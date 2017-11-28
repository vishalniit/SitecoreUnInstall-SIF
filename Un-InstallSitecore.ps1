Set-StrictMode -Version 2.0
#Please use same prefix which you used during Instalation
$prefix = "sc90"
$PSScriptRoot = "C:\Sitecore\Sitecore9.0\JSS\Sandbox"
$AntiSitecoreFile="$PSScriptRoot\AntiInstance-$prefix.json"
$body=""
$WaitTime=1
Function RemoveCertificates () {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$CertificateSubject
    )
    try {        
            Write-Host "Deleting Below Certificate:"
            $selectedcert = (Get-ChildItem -Path Cert:\LocalMachine\My -Recurse |
            Where-Object { $_.Subject -match $CertificateSubject })
            $selectedcert | FORMAT-LIST
            if($selectedcert)
            {
                $selectedcert | Remove-Item
                Write-Host 'Deleted...'
            }
    }
    catch {
        Write-Verbose $_
        Write-Host "Continuing.. "
    }        
}

Function RemoveFile () {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$FileName
    )
    $fileExist=Test-Path $FileName;
    if(!$fileExist)
    {
        Write-Host "File Not Found !!";
        return;
    }
    try {        
            Write-Host "Looking File Certificate:" +$FileName
            $selectedFile=Get-Item -Path $FileName
            if($selectedFile)
            {
                $FileName | Format-List 
                $selectedFile | Remove-Item
                Write-Host "Deleted... File"+$FileName
            }            
    }   
    catch {
        Write-Verbose $_
        Write-Host "Continuing.. "
    }        
}

Function RemoveDirectory(){
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$DirectoryPath
    )
    $directoryExist=Test-Path $DirectoryPath;
    if(!$directoryExist)
    {
        Write-Host "Directory Not Found !!";
        return;
    }
    try {        
            Write-Host "Looking Directory:" +$DirectoryPath
            Remove-Item -Recurse -Force -Confirm $DirectoryPath
            Write-Host "Deleted... Directory"+$DirectoryPath                        
    }   
    catch {
        Write-Verbose $_
        Write-Host "Continuing.. "
    }
}

function RemoveSolrCores () {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$prefix,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$SolrURL
    )
    try {
        $client = (New-Object System.Net.WebClient)      
        [xml]$coresXML = $client.DownloadString($SolrURL+"/admin/cores")
        if($coresXML){            
            $cores = $coresXML.response.lst[2].lst | % {$_.name}
            $success = 0
            $error = 0        
            foreach ($core in $cores) {
            if ($core.StartsWith($prefix)) {              
                $url = $SolrURL+"/admin/cores?action=UNLOAD&deleteIndex=true&deleteInstanceDir=true&core=$core"
                write-host "Deleting $core : from URL : $SolrURL"
                $client.DownloadString($url)
                if ($?) {$success++}
                else {$error++}
          }
        }
         write-host "Deleted $success cores.  Had $error errors."
        }
        else {
            Write-Host "No Core Found"    }
    }
    catch {
        Write-Verbose $_
        Write-Host "Continuing.. "
    }
}

Function ServiceExists([string] $ServiceName) {
    [bool] $Return = $False
    if ( Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'" ) {
        $Return = $True
    }
    Return $Return
}

# Deletes a Service with a name as defined in $ServiceName.
# Returns a boolean $True or $False.  $True if the Service didn't exist or was 
# successfully deleted after execution.
Function DeleteService([string] $ServiceName) {
    [bool] $Return = $False
    Write-Host "Trying to find service: " $ServiceName
    $Service = Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'" 
    if ( $Service ) {
        Write-Host "Deleting service: " $ServiceName
        $Service.Delete()
        if ( -Not ( ServiceExists $ServiceName ) ) {
            $Return = $True
            Write-Host "Deleting service Successfull: " $ServiceName
        }
        else{
            Write-Host "Deleting service Failed: " $ServiceName
        }
    } else {
        Write-Host "Service Not Exist: " $ServiceName
        $Return = $True
    }
    Return $Return
}

Function RemoveWebsite () {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$WebsiteName
    )
    $IISWebPath = "IIS:\Sites\"+$WebsiteName
    $IISAppPath = "IIS:\AppPools\"+$WebsiteName
    try {
        $WebExist=Test-Path $IISWebPath;
        $AppExist=Test-Path $IISAppPath;
        if(!$WebExist)
        {
            Write-Host "We didn't get website" $WebsiteName
        }
        else {
            Write-Host "We got this website" $WebsiteName
            $selectedWeb=Get-Item -Path $IISWebPath
            if($selectedWeb)
            {
                $selectedWeb | Stop-Website
                Write-Host "Waiting 10 seconds to stop Website "
                Start-Sleep -s $WaitTime
                $selectedWeb | Format-List 
                $selectedWeb | Remove-Item
                $WebDirectory=($selectedWeb).PhysicalPath
                Write-Host "Remove Direcotry: " $WebDirectory
                RemoveDirectory $WebDirectory
                Write-Host "Deleted... Website: " $WebsiteName
            }
        }    
        if(!$AppExist)
        {
            Write-Host "We didn't get App Pool" $WebsiteName
        }
        else {
            Write-Host "We got this Application Pool" $WebsiteName
            $selectedApp=Get-Item -Path $IISAppPath
            if($selectedApp)
            {
                $selectedApp | Stop-WebAppPool;
                Write-Host "Waiting 10 seconds to stop Application Pool"
                Start-Sleep -s $WaitTime
                $selectedApp | Format-List;
                $selectedApp | Remove-Item
                Write-Host "Deleted... App Pool: " $WebsiteName
            }
        }   
    }   
    catch {
        Write-Verbose $_
        Write-Host "Continuing.. "
    }        
}
# This function determines whether a database exists in the system.
function Test-SqlServer {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Server,
        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$Database,
        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$Table
    )

    if ($Database) {
        $Database = Encode-SqlName $Database
    }

    $parts = $Server.Split('\');
    $hostName = Encode-SqlName $parts[0];
    $instance = if ($parts.Count -eq 1) {'DEFAULT'} else { Encode-SqlName $parts[1] }

    #Test-Path will only fail after a timeout. Reduce the timeout for the local scope to 
    Set-Variable -Scope Local -Name SqlServerConnectionTimeout 5
    $path = "SQLSERVER:\Sql\$hostName\$instance"
    Write-Host $path
    if (!(Test-Path $path -EA SilentlyContinue)) {
        throw "Unable to connect to SQL Instance '$Server'"
        return
    }
    elseif ($Database) {
        $path = Join-Path $path "Databases\$Database"

        if (!(Test-Path $path -EA SilentlyContinue)) {
            Write-Host "Database '$Database' does not exist on server '$Server'"
            return
        }
        elseif($Table)
        {
            $parts = $Table.Split('.');
            if ($parts.Count -eq 1) {
                $Table = "dbo.$Table"
            }
            $path = Join-Path $path "Tables\$Table"

            if (!(Test-Path $path -EA SilentlyContinue)) {
                throw "Table '$Table' does not exist in database '$Database' does not exist on server '$Server'"
                return
            }
        }
    }
    $true
}

function DeleteDatabase {
    <# 
    .SYNOPSIS 
        Drops a SQL Database 
    .PARAMETER Database 
        The name of the database to drop 
    .PARAMETER Server 
        The server to drop the database from 
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Database,
        [ValidateNotNullOrEmpty()]
        [string]$Server = "."
    )

    $query = @" 
        if DB_ID('$Database') is not null 
        begin 
            exec msdb.dbo.sp_delete_database_backuphistory @database_name = N'$Database' 
            alter database [$Database] set single_user with rollback immediate 
            drop database [$Database] 
        end 
"@
    Write-Host "Query: " $query
    Invoke-Sqlcmd -ServerInstance $Server -Query $query
}

function RemoveDatabase(){
    param(
        [parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Database,
        [ValidateNotNullOrEmpty()]
        [string]$Server = "."
    )
    Write-Host "Checking if Database" $Database "exist at server " $Server
    $DbExist=Test-SqlServer $Server $Database;
    if($DbExist)
    {
        Write-Host "Trying to Remove: "$Database;
        DeleteDatabase $Database $Server ;
        $DbExist=Test-SqlServer $Server $Database;
        Write-Host "Checking again if removed : "$Database;
        if(!$DbExist){
            Write-Host "DB Deleted Successfully"
        }
        else {
            Write-Host "DB Deletion Failed"
        }
    }
    else {
        Write-Host "DB Don't Exist!!"
    }
}


function ImportModule () {
    Import-Module sqlps;
    Import-Module WebAdministration;
    #Import-Module Cert
}

function StartThis {
    [CmdletBinding()]
    $fileExist=Test-Path  $AntiSitecoreFile;
    if(!$fileExist)
    {
        Write-Host "Anti Sitecore JSON File Not Found !!";
        return;
    }
    $body = Get-Content -Path $AntiSitecoreFile -Raw | ConvertFrom-Json;
    ImportModule;
    RemoveCertificates $body.Certificates[0].xConnect
    Write-Host "Try to remove cert File: " $body.Certificates[0].xConnectCertificatePath;
    RemoveFile $body.Certificates[0].xConnectCertificatePath
    Write-Host $body.xConnectSolrParams[0].AllParams.CorePrefix
    Write-Host "Will Try to Remove Solr Cores with prefix: " $body.xConnectSolrParams[0].AllParams.CorePrefix
    RemoveSolrCores $body.xConnectSolrParams[0].AllParams.CorePrefix $body.xConnectSolrParams[0].AllParams.SolrUrl
    Write-Host "Will try to remove xConnect Windows Service:" $body.WindowsService[0].xConnectIndexWorker
    DeleteService $body.WindowsService[0].xConnectIndexWorker
    Write-Host "Will try to remove xConnect Windows Service:" $body.WindowsService[0].xConnectMarketingAutomationService
    DeleteService $body.WindowsService[0].xConnectMarketingAutomationService
    Write-Host "Will try to remove xConnect Website from IIS: "$body.xConnectInstanceParams[0].AllParams.Sitename
    RemoveWebsite $body.xConnectInstanceParams[0].AllParams.Sitename
    RemoveDatabase $body.Databases[0].xConnectProcessingDB $body.xConnectInstanceParams[0].AllParams.SqlServer
    RemoveDatabase $body.Databases[0].xConnectMarketingAutomationDB $body.xConnectInstanceParams[0].AllParams.SqlServer
    RemoveDatabase $body.Databases[0].xConnectReferenceDataDB $body.xConnectInstanceParams[0].AllParams.SqlServer
    RemoveDatabase $body.Databases[0].xConnectCollectionShard0DB $body.xConnectInstanceParams[0].AllParams.SqlServer
    RemoveDatabase $body.Databases[0].xConnectCollectionShard1DB $body.xConnectInstanceParams[0].AllParams.SqlServer
    RemoveDatabase $body.Databases[0].xConnectShardMapManagerDB $body.xConnectInstanceParams[0].AllParams.SqlServer
    #$body | ConvertTo-Json -Depth 10   
}

StartThis
