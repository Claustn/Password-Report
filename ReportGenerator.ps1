#requires -Version 2 -Modules EnhancedHTML2
Import-Module -Name PSSQLite
$SQLLiteDB = 'C:\temp\UserDB.db'
$ReportPath = 'D:\usertest.html'

$QueryUsersWithSamePassword = @"
SELECT DisplayName,NTHash,ClearTxtPWD,DistinguishedName FROM USERS
LEFT JOIN PWDTranslation
On USERS.NTHash=PWDTranslation.Hash
WHERE NTHash IN 
 (SELECT NTHash FROM Users
  GROUP BY NTHash  HAVING COUNT (NTHash) >1)
  ORDER BY NTHash
"@
$UsersWithTheSamePassword = Invoke-SqliteQuery -Query $QueryUsersWithSamePassword -DataSource $SQLLiteDB  

#Get Currently Most Used Password/Hash

$QueryCurrentlyMostUsedHash = @"
SELECT Count(*) HashCount, NTHash,ClearTxtPWD 
FROM USERS 
LEFT JOIN PWDTranslation
On USERS.NTHash=PWDTranslation.Hash
GROUP BY USERS.NTHash
HAVING HashCount > 1
Order By HashCount Desc
"@

$CurrentlyMostUsedHash = Invoke-SqliteQuery -Query $QueryCurrentlyMostUsedHash -DataSource $SQLLiteDB  

#Most used password historically

$QueryMostUsedHashHistorically = @"
SELECT Count(*) HashCount, HashHistory .HASH,ClearTxtPWD 
FROM HashHistory 
LEFT JOIN PWDTranslation
On HashHistory.Hash=PWDTranslation.Hash
GROUP BY HashHistory.Hash
HAVING HashCount > 1
Order By HashCount Desc
"@

$HistoricallyMostUsedHash = Invoke-SqliteQuery -Query $QueryMostUsedHashHistorically -DataSource $SQLLiteDB  

#Users with Weak Password

$QueryUsersWithWeakPassword = @"
SELECT DisplayName,
					UserPrincipalName,
					COALESCE (GUID ,0) AS Guid,
					ClearTxtPWD
FROM  PWDTranslation
LEFT JOIN USERS
On Users.NTHash = PWDTranslation.Hash
Where Guid <> 0
"@
$UsersWithWeakPassword = Invoke-SqliteQuery -Query $QueryUsersWithWeakPassword -DataSource $SQLLiteDB  

$queryMostUsedHashes = @"
SELECT  hh.hash,u.DisplayName, u.DistinguishedName, pt.ClearTxtPWD
FROM Users u INNER JOIN HashHistory hh
ON u.GUID = hh.GUID JOIN PWDTranslation pt
ON hh.Hash = pt.hash
"@

$MostUsedHashes = Invoke-SqliteQuery -Query $queryMostUsedHashes -DataSource $SQLLiteDB

$QueryUsersWhoHaveReusedTheirPasswords = @"
CREATE TEMPORARY TABLE ParentChild AS
SELECT * FROM USERS u INNER JOIN HashHistory hh ON u.GUID = hh.GUID ;
 
Select DisplayName, pc.Hash, ClearTxtPWD, Count(*) as HashCount
 FROM ParentChild pc  LEFT OUTER JOIN PWDTranslation pwd
 ON pc.Hash = pwd.hash
Group By DisplayName, pc.Hash, ClearTxtPWD
HAVING HashCount > 1
Order By hashCount DESC;
"@

$UsersWhoHaveReusedTheirPasswords = Invoke-SqliteQuery -Query $QueryUsersWhoHaveReusedTheirPasswords -DataSource $SQLLiteDB


$QueryUsersWithBlankPassword = @"
SELECT * 
FROM USERS
WHERE NTHash = '31d6cfe0d16ae931b73c59d7e0c089c0';
"@

$UsersWithBlankPassword = Invoke-SqliteQuery -Query $QueryUsersWithBlankPassword -DataSource $SQLLiteDB

$QueryUsersWhoHaveHadBlankPassword = @"
SELECT DisplayName, SamAccountName, Enabled, LastLogon, NTHash 
FROM USERS u INNER JOIN HashHistory hh ON u.GUID = hh.GUID
WHERE Hash == '31d6cfe0d16ae931b73c59d7e0c089c0'
"@

$UsersWhoHaveHadBlankPassword = Invoke-SqliteQuery -Query $QueryUsersWhoHaveHadBlankPassword -DataSource $SQLLiteDB

$QueryUsersWhoHaveNeverChangedPassword = @"
Select DisplayName, SamAccountName, Enabled, LastLogon, NTHash, PWDTranslation.ClearTxtPWD
FROM USERS LEFT JOIN PWDTranslation
ON USERS.NTHash = PWDTranslation.Hash
WHERE NTHashHistoryCount == 1
"@
$UsersWhoHaveNeverChangedPassword = Invoke-SqliteQuery -Query $QueryUsersWhoHaveNeverChangedPassword -DataSource $SQLLiteDB


$style = @"
<style>
body {
    color:#333333;
    font-family:Calibri,Tahoma;
    font-size: 10pt;
}
h1 {
    text-align:center;
}
h2 {
    border-radius: 25px;
    border: 2px solid #73AD21
    padding: 20px;
    border: 3px solid gray;
    margin: 5px;
    width: 650px;
    height: 30px;
    text-align: center;
    background-color: #66ccff;   
}

th {
    font-weight:bold;
    color:#eeeeee;
    background-color:#333333;
    cursor:pointer;
}
.odd  { background-color:#ffffff; }
.even { background-color:#dddddd; }
.paginate_enabled_next, .paginate_enabled_previous {
    cursor:pointer; 
    border:1px solid #222222; 
    background-color:#dddddd; 
    padding:2px; 
    margin:4px;
    border-radius:2px;
}
.paginate_disabled_previous, .paginate_disabled_next {
    color:#666666; 
    cursor:pointer;
    background-color:#dddddd; 
    padding:2px; 
    margin:4px;
    border-radius:2px;
}
.dataTables_info { margin-bottom:4px; }
.sectionheader { cursor:pointer; }
.sectionheader:hover { color:red; }
.grid { width:100% }
.red {
    color:red;
    font-weight:bold;
} 
</style>
"@

Function Get-UsersWithTheSamePassword 
{
  $UsersWithTheSamePassword |
  Group-Object -Property nthash  |
  Sort-Object -Property count -Descending |
  ForEach-Object -Process {
    $Props = @{
      count                = $_.Count
      Hash                 = $_.Name
      'UserName(s)'        = $_.Group |
      ForEach-Object -Process {
        "$($_.DisplayName)<br>"
      }
      Password             = $_.Group.ClearTxtPWD |
      Select-Object -First 1
      'DistinguishedName(s)' = $_.Group |
      ForEach-Object -Process {
        "$($_.DistinguishedName)<br>"
      }
    }
    New-Object -TypeName PSObject -Property $Props
  }
}

$UsersWithTheSamePassword = Get-UsersWithTheSamePassword

$params = @{
  'As'              = 'Table'
  'PreContent'      = "<h2> Current users with the same Password ($(@($UsersWithTheSamePassword).Count))</h2>"
  'MakeTableDynamic' = $true
  'MakeHiddenSection' = $false
  'TableCssClass'   = 'grid'
  'Properties'      = 'Count', 'Hash', 'Password', 'UserName(s)', 'DistinguishedName(s)'
}
$html_UserWithTheSamePassword = $UsersWithTheSamePassword |
ConvertTo-EnhancedHTMLFragment @params 

$params = @{
  'As'              = 'Table'
  'PreContent'      = "<h2> Historically most used Hashes/Passwords ($(@($HistoricallyMostUsedHash).count))</h2>"
  'MakeTableDynamic' = $true
  'MakeHiddenSection' = $false
  'TableCssClass'   = 'grid'
  'Properties'      = 'HashCount', 'Hash', 'ClearTxtPWD'
}
$html_HistoricallyMostUsedHashes = $HistoricallyMostUsedHash  |
ConvertTo-EnhancedHTMLFragment @params 


$params = @{
  'As'              = 'Table'
  'PreContent'      = "<h2> Users who have reused their Password(s) ($(@($UsersWhoHaveReusedTheirPasswords).Count))</h2>"
  'MakeTableDynamic' = $true
  'MakeHiddenSection' = $false
  'TableCssClass'   = 'grid'
  'Properties'      = 'HashCount', 'Hash', 'ClearTxtPWD', 'DisplayName'
}

$html_UsersWhoHaveReusedTheirPasswords = $UsersWhoHaveReusedTheirPasswords |
ConvertTo-EnhancedHTMLFragment @params 


$params = @{
  'As'              = 'Table'
  'PreContent'      = "<h2> Current users with `"Weak/Known`" Passwords ($(@($UsersWithWeakPassword).count)) </h2>"
  'MakeTableDynamic' = $true
  'MakeHiddenSection' = $false
  'TableCssClass'   = 'grid'
  'Properties'      = 'DisplayName', 'UserPrincipalName', 'ClearTxtPWD'
}
$html_UsersWithWeakPasswords = $UsersWithWeakPassword | 
ConvertTo-EnhancedHTMLFragment @params 

$params = @{
  'As'              = 'Table'
  'PreContent'      = "<h2> Users who have never changed Password ($(@($UsersWhoHaveNeverChangedPassword).count))</h2>"
  'MakeTableDynamic' = $true
  'MakeHiddenSection' = $false
  'TableCssClass'   = 'grid'
  'Properties'      = 'DisplayName', 'samAccountName', 'Enabled', 'NTHash', 'ClearTxtPWD'
}
$html_UsersWhoHaveNeverChangedPassword  = $UsersWhoHaveNeverChangedPassword  | 
ConvertTo-EnhancedHTMLFragment @params 

$params = @{
  'As'              = 'Table'
  'PreContent'      = "<h2> Users who have had a blank Password ($(@($UsersWhoHaveHadBlankPassword).count))</h2>"
  'MakeTableDynamic' = $true
  'MakeHiddenSection' = $false
  'TableCssClass'   = 'grid'
  'Properties'      = 'DisplayName', 'samAccountName', 'Enabled', 'NTHash', 'ClearTxtPWD'
}
$html_UsersWhoHaveHadBlankPassword  = $UsersWhoHaveHadBlankPassword  | 
ConvertTo-EnhancedHTMLFragment @params 

$params = @{
  'As'              = 'Table'
  'PreContent'      = "<h2> Users with a blank Password ($(@($UsersWithBlankPassword).count))</h2>"
  'MakeTableDynamic' = $true
  'MakeHiddenSection' = $false
  'TableCssClass'   = 'grid'
  'Properties'      = 'DisplayName', 'samAccountName', 'Enabled', 'NTHash', 'ClearTxtPWD'
}
$html_UsersWithBlankPassword   = $UsersWithBlankPassword   | 
ConvertTo-EnhancedHTMLFragment @params 


$params = @{
  'CssStyleSheet'    = $style
  'Title'            = 'User Report'
  'PreContent'       = '<h1>AD User Analysis</h1>'
  'HTMLFragments'    = @($html_UsersWithWeakPasswords, $html_UserWithTheSamePassword, 
    $html_UsersWhoHaveReusedTheirPasswords, $html_HistoricallyMostUsedHashes, $html_UsersWhoHaveNeverChangedPassword, 
  $html_UsersWhoHaveHadBlankPassword, $html_UsersWithBlankPassword )
  'jQueryDataTableUri' = 'http://ajax.aspnetcdn.com/ajax/jquery.dataTables/1.9.3/jquery.dataTables.min.js'
  'jQueryUri'        = 'http://ajax.aspnetcdn.com/ajax/jQuery/jquery-1.8.2.min.js'
} 
ConvertTo-EnhancedHTML @params |
Out-File -FilePath $ReportPath

. D:\usertest.html
<#
    $params = @{'CssStyleSheet'=$style;
    'Title'="System Report for $computer";
    'PreContent'="<h1>System Report for $computer</h1>";
    'HTMLFragments'=@($html_os,$html_cs,$html_dr,$html_pr,$html_sv,$html_na)}
    ConvertTo-EnhancedHTML @params |
    Out-File -FilePath $filepath
#>