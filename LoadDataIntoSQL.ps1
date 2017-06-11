Import-Module -Name PSSQLite   
#InsertInto DB

#Path to SqlLite database
$SQLLiteDB = 'C:\temp\UserDB.db'
#Load the list of "known/guessed/assumed" passwords
$Passwords = Get-Content  -Path C:\temp\Passwords.txt

# Constant
$BlankPasswordNThash = '31d6cfe0d16ae931b73c59d7e0c089c0'

#Load all users using Get-ADReplAccount from the DSInternals modules from Michael Grafnetter
'Time to Load allUsers'
Measure-Command -Expression {
  $Accounts = Get-ADReplAccount -All -Server localhost -NamingContext 'DC=adpwdtest,DC=net'
}

$TruncateTables = @"
DELETE FROM USERS;
DELETE FROM PWDTranslation;
DELETE FROM HashHistory;
"@

#Truncate existing data in the database
Invoke-SqliteQuery -Query $TruncateTables -DataSource $SQLLiteDB

#Loading the known passwords into the into SqlLite database
#These are the password that we have guessed might have been used
'Time to Load Passwords into SQLIte'
Measure-Command -Expression {
  $PasswordTableDT = $Passwords |
  ForEach-Object -Process {
    [pscustomobject]@{
      Hash        = ConvertTo-NTHash $(ConvertTo-SecureString -String $_ -AsPlainText -Force)
      ClearTxtPWD = $_
    }
  } |
  Out-DataTable

  $QueryInsertBlankPWD = 'INSERT INTO  PWDTranslation (Hash, ClearTxtPWD) VALUES (@Hash, @ClearTxtPWD)'

  Invoke-SqliteQuery -Query $QueryInsertBlankPWD -DataSource $SQLLiteDB -SqlParameters @{
    ClearTxtPWD = '<Blank>'
    Hash        = $BlankPasswordNThash
  }


  Invoke-SQLiteBulkCopy -DataTable $PasswordTableDT -DataSource $SQLLiteDB -Table PWDTranslation -Force
}


#Add user objects and their hash history into the database.
'Time To create Users and HashHistory objects'

Measure-Command -Expression {
  $AccountOBJ = @()
  $HashHistoryOBJ = @()
  Foreach ($Account in $Accounts)
  {
    If ($Account.NTHashHistory)
    {
      $NTPasshistory = ($Account.NTHashHistory).Count
    }
    Else
    {
      $NTPasshistory = 0
    }
	
    $AccountOBJ += [pscustomobject]@{
      Guid               = $($Account.guid.guid)
      DistinguishedName  = $Account.distinguishedName
      SamAccountName     = $Account.SamAccountName
      SamAccountType     = $Account.SamAccountType
      UserPrincipalName  = $Account.UserPrincipalName
      DisplayName        = $Account.DisplayName
      Enabled            = $Account.Enabled
      LastLogon          = $Account.LastLogon
      NTHash             = $(if ($Account.NTHash) 
        {
          $(ConvertTo-Hex $($Account.NTHash)) 
        }
      )
      NTHashHistoryCount = $NTPasshistory
    }
	
    $HashHistoryOBJ += $Account.NTHashHistory |  ForEach-Object -Process {
      if ($Account.NTHashHistory)
      {
        [pscustomobject]@{
          guid = $($Account.guid.guid)
          Hash = $(ConvertTo-Hex $_)
        }
      }
    }
  }
}

'Insert HashHistory'
Measure-Command -Expression {
  Invoke-SQLiteBulkCopy -DataTable $($HashHistoryOBJ | Out-DataTable) -DataSource $SQLLiteDB -Table HashHistory -Force
}
'Insert Accounts'

Measure-Command -Expression {
  Invoke-SQLiteBulkCopy -DataTable $($AccountOBJ | Out-DataTable) -DataSource $SQLLiteDB -Table Users -Force
}



