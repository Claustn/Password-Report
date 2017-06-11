#Here I install the modules directly from the PowerShell gallery, since this is just a demo. These could be downloaded in advance and vetted for security issues then copied manually.
Install-Module -Name DSinternals -Scope AllUsers
Install-Module -Name PSSQLite -Scope AllUsers
Install-Module -Name EnhancedHTML2 -Scope AllUsers
Import-Module -Name PSSQLite


#Path to SqlLite database
$SQLLiteDB = 'C:\temp\UserDB.db'

#Drop all tables that we have created
$SQLDropTables = @"
DROP TABLE USERS;
DROP TABLE HashHistory;
DROP TABLE PWDTranslation;
"@


#Create  SQL lite database
$CreateUserTable = @"
CREATE TABLE USERS (Guid TEXT PRIMARY KEY,
 DistinguishedName TEXT,
 SamAccountName TEXT,
 SamAccountType TEXT,
 UserPrincipalName TEXT,
 Enabled TEXT,
 LastLogon DATETIME,
 NTHash TEXT,
 NTHashHistoryCount Integer,
 DisplayName TEXT)
"@
$CreateNTHashTable = 'CREATE TABLE HashHistory (Guid TEXT, HASH TEXT)'
$CreatePWDTable = 'CREATE TABLE PWDTranslation (Hash TEXT, ClearTxtPWD TEXT)'


If (Test-Path $SQLLiteDB) {
Invoke-SqliteQuery -Query $SQLDropTables -DataSource $SQLLiteDB
}
Invoke-SqliteQuery -Query $CreateUserTable -DataSource $SQLLiteDB
Invoke-SqliteQuery -Query $CreateNTHashTable -DataSource $SQLLiteDB
Invoke-SqliteQuery -Query $CreatePWDTable -DataSource $SQLLiteDB



Invoke-SqliteQuery -DataSource $SQLLiteDB -Query 'PRAGMA table_info(NAMES)'