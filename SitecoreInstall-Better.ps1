#define parameters 
#Please define unique Prefix so that it 
#is easy to find "&" easy to delete if required.
$prefix = "sc90"
$PSScriptRoot = "C:\Sitecore\Sitecore9.0\JSS\Sandbox"
$XConnectCollectionService = "$prefix.xconnect"
$sitecoreSiteName = "$prefix.local"
$SolrUrl = "https://localhost:8983/solr"
$SolrRoot = "C:\Solr\solr-6.6.2"
$SolrService = "Solr6.6.2"
$SqlServer = "E4ML19101"
$SqlAdminUser = "sa"
$SqlAdminPassword = "Hello"
$xConnectFile= "Sitecore 9.0.0 rev. 171002 (OnPrem)_xp0xconnect.scwdp.zip"
$xpInstallFile= "Sitecore 9.0.0 rev. 171002 (OnPrem)_single.scwdp.zip"
$AntiInstance="$PSScriptRoot\AntiInstance-$prefix.json"
$CertificatePath="C:\certificates"
#below variables will be generated as part of script execution
$certParams;
$solrParams;
$xconnectParams;
$solrWebParams;
$sitecoreParams;
function InstallSitecore () {
    $certParams = 
    @{     
        Path = "$PSScriptRoot\xconnect-createcert.json"     
        CertificateName = "$prefix.xconnect_client" 
    }
    $solrParams = 
    @{
        Path = "$PSScriptRoot\xconnect-solr.json"     
        SolrUrl = $SolrUrl    
        SolrRoot = $SolrRoot  
        SolrService = $SolrService  
        CorePrefix = $prefix 
    }
    $xconnectParams = 
    @{
        Path = "$PSScriptRoot\xconnect-xp0.json"     
        Package = "$PSScriptRoot\$xConnectFile"
        LicenseFile = "$PSScriptRoot\license.xml"
        Sitename = $XConnectCollectionService   
        XConnectCert = $certParams.CertificateName    
        SqlDbPrefix = $prefix  
        SqlServer = $SqlServer  
        SqlAdminUser = $SqlAdminUser
        SqlAdminPassword = $SqlAdminPassword
        SolrCorePrefix = $prefix
        SolrURL = $SolrUrl      
    }
    $solrWebParams = 
    @{
        Path = "$PSScriptRoot\sitecore-solr.json"
        SolrUrl = $SolrUrl
        SolrRoot = $SolrRoot
        SolrService = $SolrService     
        CorePrefix = $prefix 
    }
    $sitecoreParams = 
    @{     
        Path = "$PSScriptRoot\sitecore-XP0.json"
        Package = "$PSScriptRoot\$xpInstallFile" 
        LicenseFile = "$PSScriptRoot\license.xml"
        SqlDbPrefix = $prefix  
        SqlServer = $SqlServer  
        SqlAdminUser = $SqlAdminUser     
        SqlAdminPassword = $SqlAdminPassword     
        SolrCorePrefix = $prefix  
        SolrUrl = $SolrUrl     
        XConnectCert = $certParams.CertificateName     
        Sitename = $sitecoreSiteName         
        XConnectCollectionService = "https://$XConnectCollectionService"    
    }
     try {
            #install client certificate for xconnect
            Install-SitecoreConfiguration @certParams -Verbose    
            #install solr cores for xdb         
            Install-SitecoreConfiguration @solrParams -Verbose    
            #deploy xconnect instance         
            Install-SitecoreConfiguration @xconnectParams -Verbose    
            #install solr cores for sitecore         
            Install-SitecoreConfiguration @solrWebParams -Verbos     
            #install sitecore instance         
            Install-SitecoreConfiguration @sitecoreParams -Verbose
    }
    catch {
        Write-Verbose $_
    }
    finally
    {
        Write-Host "Writing $AntiInstance, use it for un-install through Un-InstallSitecore.ps1";
        #Writing to JSON    
        $body=[ordered]@{
            'Certificates'=@(@{
                'xConnect'=$certParams.CertificateName
                'xConnectCertificatePath'="$CertificatePath\"+$certParams.CertificateName+".crt"
            })
            'WindowsService'=@(@{
                'xConnectIndexWorker'="$XConnectCollectionService-IndexWorker"
                'xConnectMarketingAutomationService'="$XConnectCollectionService-MarketingAutomationService"
            })   
            'Databases'=@(@{
                'xConnectProcessingDB'=$prefix+"_Processing.Pools"
                'xConnectMarketingAutomationDB'=$prefix+"_MarketingAutomation"
                'xConnectReferenceDataDB'=$prefix+"_ReferenceData"
                'xConnectCollectionShard0DB'=$prefix+"_Xdb.Collection.Shard0"
                'xConnectCollectionShard1DB'=$prefix+"_Xdb.Collection.Shard1"
                'xConnectShardMapManagerDB'=$prefix+"_Xdb.Collection.ShardMapManager"
            })  
            'xConnectSolrParams'=@(@{
                AllParams=$solrParams
            })
            'xConnectInstanceParams'=@(@{
                AllParams=$xconnectParams
            })
            'SitecoreSolrParams'=@(@{
                AllParams=$solrWebParams
            })
            'SitecoreInstanceParams'=@(@{
                AllParams=$sitecoreParams
            })
        }
        $body | ConvertTo-Json -Depth 10 | Out-File -Encoding Ascii  -FilePath $AntiInstance
    }   
}
InstallSitecore;



