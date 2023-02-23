# ssms-registered-server-import

This script / directory structure allows for seeding in registered server lists into SSMS. 

### Usage
1. Add one or more server definition json files in the server_lists directory (see below)
2. Add a credentials.json file in the same directory as the import script
3. Execute import_servers.ps1

### Server Definitions 
Server definitions can be in one or multiple files and specify the following fields:
1. server: the network name of the sql server
2. db: the name of the database 
3. credential_name: the name of a credential supplied in the credentials.json file 
4. user: the username for this connection if credential_name is not supplied
5. pass: the password for this connection if credential_name is not supplied

An example server definition file might look like the following:

```
[
    {
        "server": "SQL_SERVER_NAME",
        "db": "DATABASE",
        "credential_name":"my_credential",
        "user":"my_sql_auth_username", 
        "pass":"my_sql_auth_password", 
        "registration_name":"DATABASE", 
        "path":"server_folder_path"
    }       
]
```
### Credential Definition (credentials.json) 
Specifying named credentials in the credentials.json file allows allows for configuring reusable credentials and for storing credentials in an external/local file that isn't tied to a given repository.

Credential definitions must be saved in a credentials.json file found at the same path as the import_servers.ps1 file. Credential definitions have the following format:

1. name: the identifier used by a server registration to reference the credential
4. user: the username for connections using this credential
5. pass: the password for connections using this credential

An example credential.json file might look like the following:

```
[
    {
        "name": "my_credential",
        "user": "my_username",
        "pass": "my_password"
    }
]
```