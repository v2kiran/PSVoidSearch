function Get-VTSearch
{
    [CmdletBinding()]
    [Alias('vt')]
    Param
    (

        [parameter(Position=0)]
        [String[]]
        $FileName,
        
        [parameter(Position=3)]              
        [String]
        $Path,

        [String]
        $Exclude,
        
        # Find files of a particular type easily.
        [parameter(Position=2)]
        [String[]]
        $Extension,   
        
        # Find files of a particular type easily using fixed extensions
        [parameter(Position=1)]
        [Validateset('Video','Audio','Compressed','Document','Executable','Picture','Everything')]
        [String]
        $Filter,           

        # Returns filenames only
        [Switch]
        $NoObject,

        # Search is recursive by default set this to make search non-recursive
        [Switch]
        $NoRecurse,

        [Parameter(ParameterSetName = 'Dupe')]
        [Switch]
        $ShowDuplicates,

        [Parameter(ParameterSetName = 'Empty')]
        [Switch]
        $ShowEmptyFolders,
        
        [Parameter(ParameterSetName = 'Long')]
        [Switch]
        $ShowLongFolders,        
        
        [parameter(ParameterSetName = 'Size')]
        [uint32]
        $SizeGreaterThan,
        
        [parameter(ParameterSetName = 'Size')]
        [uint32]
        $SizeLessThan,
        
        [Validateset('Auto','Bytes','KB','MB')]
        [string]
        $SizeFormat = 'MB',

        [uint32]
        $Limit,    

        [uint32]
        $Depth,          
        
        [Switch]
        $File,

        [Switch]
        $Folder,      
        
        [Switch]
        $Name,     
        
        [parameter(ParameterSetName = 'regex',Mandatory)]
        [string]
        $Regex
           
    )

	Begin
	{
		if(-not (Get-Process everything | Where-Object path -ne $null))
        {
            Start-Process -FilePath "$($env:ProgramFiles)\Everything\Everything.exe" -WindowStyle Hidden 
            sleep -Milliseconds 60
        }
        
        #Set the path to the voidtools ES.exe commandline executable
		$Global:ESpath = Join-Path -Path $PSScriptRoot -ChildPath app\es.exe

		
	}
    Process
    {
        
		$Script:Query = New-Object System.Collections.ArrayList

		if(-not [string]::IsNullOrEmpty($FileName))
		{		
			if($FileName -is [Array])
			{
				$NewName = '(""' + ($FileName -join '""|""') + '"")'
			}
			Else
			{
				$NewName = '(""' + $FileName + '"")'
			}

			$query.Add($NewName) | Out-Null
		}
        
        
        
        if($PSBoundParameters.ContainsKey('Extension'))
        {
            $Customextension = 'ext' + ':' + ($extension -join ';')
            $query.Add($Customextension) | Out-Null
        }


        if($PSBoundParameters.ContainsKey('Exclude'))
        {
            $query.Add("!$Exclude") | Out-Null
        } 

        if ($Path) 
        {
            if($PSBoundParameters.ContainsKey('NoRecurse'))
            {
                $query.Add("parent:$path") | Out-Null
            } 
            else 
            {
                $query.Add("-path `"$Path`"") | Out-Null
            }
        }


        if($PSBoundParameters.ContainsKey('ShowDuplicates'))
        {
            if (-not [string]::IsNullOrEmpty($FileName))
            {
                $query.Add("dupe:$NewName") | Out-Null
            }
            else
            {
                $query.Add('dupe:') | Out-Null
            
            }            
        }
        
        if($PSBoundParameters.ContainsKey('ShowEmptyFolders'))
        {
            $query.Add('empty:') | Out-Null
        }
        if($PSBoundParameters.ContainsKey('SizeGreaterThan'))
        {
            $query.Add("size:gt:$SizeGreaterThan$SizeUnit") | Out-Null
        }    
        if($PSBoundParameters.ContainsKey('SizeLessThan'))
        {
            $query.Add("size:lt:$SizeLessThan$SizeUnit") | Out-Null
        }  
        if($PSBoundParameters.ContainsKey('ShowLongFolders'))
        {
            $query.Add('path:len:gt:260') | Out-Null
        }                           
        if($Filter) 
        {
            $query.Add("type:$Filter") | Out-Null
        }
        if($PSBoundParameters.ContainsKey('Limit'))
        {
            $query.Add("-n $Limit") | Out-Null
        } 

        if ($File) 
        {
            $query.Add("file:") | Out-Null
        }

        if ($Folder) 
        {
            $query.Add("folder:") | Out-Null
        }   

        if ($Depth) 
        {
            $query.Add("depth:$depth") | Out-Null
        }  

        if ($Regex) 
        {
            $query.Add("regex:$regex") | Out-Null
        }         
        
        
        switch ($SizeFormat) 
        {
            'Auto' { $query.Add("-sizeformat 0") | Out-Null }
            'Bytes' {$query.Add("-sizeformat 1") | Out-Null}
            'KB' { $query.Add("-sizeformat 2") | Out-Null }
            'MB' {$query.Add("-sizeformat 3") | Out-Null}            
        }
        
        if ($NoObject -or $Name) 
        {
            if ($Name) 
            {
                $query.AddRange(@('-name')) | Out-Null
            }
        }
        else 
        {
            $query.AddRange(@('-pathcolumn','-pathwidth 255','-filenamecolumn','-filenamewidth 255','-dm','-dmwidth 50','-name','-namewidth 255','-attributes','-attributeswidth 10','-size','-sizewidth 20' )) | Out-Null
        }


$str = @"
&'$espath' --%  $query
"@


        Write-Verbose "Query:`t`t$query"
        $results = @(([scriptblock]::Create($str)).invoke())

        
        if($results.Count -gt 0)
        {
        
            if ($NoObject -or $Name)
            {
                $results
            }
            else
            {
                $results.ForEach({
                    $fDirectory,$FullName,$LastWriteTime,$fName,$Mode,$Length = $_ -split '\s{5,255}'

                    # Create the custom object
                    [PSCustomObject]@{
                        PSTypeName = "PSCustomObject.VoidTools"
                        Mode=$Mode.Trim()
                        Directory=$fDirectory.Trim()
                        FullName = $FullName.Trim()
                        LastWriteTime=[datetime]$LastWriteTime
                        Length = $Length.Trim()
                        Name= $fName.Trim()
                        BaseName=[IO.Path]::GetFileNameWithoutExtension($FullName)
                        Extension = [IO.Path]::GetExtension($FullName)
                    } 

                })                
                #$results                              
            }
                             
          
        }# if results
        Else
        {
            Write-Warning 'No Results'
        }                 
        
             

    }#process
    End
    {
    }
}




