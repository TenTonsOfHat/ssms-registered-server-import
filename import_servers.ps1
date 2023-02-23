<#
.SYNOPSIS
    This script allows you to generate ssms registered server entries that use SQL Authentication (windows auth isn't yet supported)
.DESCRIPTION
    This script syncs Areas, Views, App_Themes, App_Code, Scripts, and js directories 
    USAGE: 
        + configure servers in json files within the server_lists directory
            + all json files within this directory will be read
        + add credentials to credentials.json (if you didn't include them in the server definitions)

    SERVER LISTS:
        Server list files contain sets of registered servers
        Example file content:
        [
            {
                "server": "SQL_SERVER_NAME", // the name of the server
                "db": "DATABASE", // the database on the server
                "credential_name":"my_credential", // the name of the credential from credentials.json
                "user":"my_sql_auth_username", // the username for this connection if credential_name is not supplied
                "pass":"my_sql_auth_password", // the password for this connection if credential_name is not supplied
                "registration_name":"DATABASE", // the name that shows up in ssms
                "path":"server_folder_path" // the path the registration shows up at in ssms
            }       
        ]

    CREDENTIAL FILE: 
        Allows for configuring reusable credentials and for storing credentials in an external/local file
        Example credentails.json content
        [
            {   "name": "my_credential", // the value passed into credential_name in a server definition
                "user":"my_sql_auth_username", 
                "pass":"my_sql_auth_password"
            }
        ]
#>



# this is the path that registrations are stored at after importing the sql module
$global:sql_server_group_path = "sqlserver:\SQLRegistration\Database Engine Server Group"

# the location of a shared credential file that can be 
# used instead of setting user/pass on every connection object, its format is 
# [ {"name": "credentail_name","user":"username_for_credential", "pass":"password_for_credential"} ]
$global:credential_json_path =  Join-Path $PSScriptRoot "credentials.json"

# the path that lists of server.json files can be found
$global:server_lists_path =  Join-Path $PSScriptRoot "server_lists"

function main(){
    Set-Location -Path $global:sql_server_group_path;
    $server_data = Get-Server-Data
    
    foreach($server in $server_data){
        $group_path = Join-Path $global:sql_server_group_path $server.path

        # create the server group path
        Add-Server-Groups $group_path
        Add-Server-Registration $server $group_path
    } 
}

function Get-Credential-Data {
    if(Test-Path $global:credential_json_path){
        $text = [System.IO.File]::ReadAllText($global:credential_json_path)
        $cred_data = ConvertFrom-Json $text
        $credentials = $cred_data |  ForEach-Object  {[CredentialDefinition]::new($_)} 
        #get the unique list by name
        $credentials = $credentials | Group-Object -Property name | ForEach-Object { $_.Group[0] }
        return $credentials
    }
    return [CredentialDefinition]@()
}

function Get-Server-Data {
    $server_list =@()
    $server_files = (Get-ChildItem -Path ($global:server_lists_path) -Filter *.json);
    foreach($server_file in $server_files){
        $text = [System.IO.File]::ReadAllText($server_file.FullName)
        $server_data = ConvertFrom-Json $text
        foreach($server_json in $server_data){
            $server_list += [ServerDefinition]::new($server_json)
        }
    }

    $credentials = Get-Credential-Data; 
    foreach($server in $server_list){
        if($null -ne $server.credential_name){
            $cred = ($credentials | Where-Object { $_.name -eq $server.credential_name})[0]
            if($null -ne $cred){
                $server.user = $cred.user;
                $server.pass = $cred.pass
            }
        }
    }

    #get the unique list by registration/path
    $server_list = $server_list | Group-Object -Property registration_name, path | ForEach-Object { $_.Group[0] }
    return $server_list
}


function Get-Connection-String($server_data){
    $conn_string_template = 'data source={0};initial catalog={1};user id={2};password="{3}";pooling=False;multipleactiveresultsets=False;connect timeout=30;encrypt=False;trustservercertificate=False;packet size=4096;'
    return [string]::Format($conn_string_template,$server_data.server, $server_data.db, $server_data.user, $server_data.pass)
}

#Adds a new server registration, deletes the existing one if it's already there
function Add-Server-Registration($server, $group_path){
    $connection_string = Get-Connection-String $server
    $registration_name = "$(Encode-Sqlname $server.registration_name)"
    $path = Join-Path $group_path $registration_name

    if((Test-Path $path) -eq $true){
        Write-Output "Removing Existing Registration: $path"
        Remove-Item "$path"
    }
    
    Write-Output "Adding Registration: $path"
    New-Item "$path" -ItemType Registration -Value $connection_string -Force
}

# Recursively adds registered server groups (b/c you cant add them all at once)
function Add-Server-Groups($path) {
   $parent = Split-Path $path 

   if($parent -ne $global:sql_server_group_path){
     Add-Server-Groups $parent
   }
   
    if((Test-Path $path) -ne $true){
        Write-Output "Creating $path"
        New-Item -Path "$path"
    }
}


function Load-Module ($m) {

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host "Module $m is already imported."
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Import-Module $m 
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
                Install-Module -Name $m -Force -Scope CurrentUser
                Import-Module $m -Verbose
            }
            else {

                # If the module is not imported, not available and not in the online gallery then abort
                write-host "Module $m not imported, not available and not in an online gallery, exiting."
                EXIT 1
            }
        }
    }
}

Load-Module "SqlServer"

main 






class ServerDefinition {
    [string] $user
    [string] $pass
    [string] $server
    [string] $db
    [string] $credential_name
    [string] $registration_name
    [string] $path
    
    ServerDefinition(){}

    ServerDefinition([PSCustomObject] $server){
        $properties = $this.GetType().GetProperties() | Where-Object {$_.MemberType -eq 'Property'} | ForEach-Object {$_.Name};
        foreach($prop in $properties){
            $has_prop =  [bool]($server.PSobject.Properties.name -match $prop)
            if($has_prop){
                $this.$prop = $server.$prop
            }
        }
    }
}

class CredentialDefinition {
    [string] $user
    [string] $pass
    [string] $name
    
    CredentialDefinition(){}

    CredentialDefinition([PSCustomObject] $cred){
        $properties = $this.GetType().GetProperties() | Where-Object {$_.MemberType -eq 'Property'} | ForEach-Object {$_.Name};
        foreach($prop in $properties){
            $has_prop =  [bool]($cred.PSobject.Properties.name -match $prop)
            if($has_prop){
                $this.$prop = $cred.$prop
            }
        }
    }
}