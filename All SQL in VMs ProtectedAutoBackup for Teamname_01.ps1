$team = @('xxx', 'yyy', 'zz')
$backupRG = @('rg-xxx-prod-backup', 'rg-yyy-prod-backup','rg-zzz-prod-backup')
$Location = 'West Europe'
$backupRSVault = @('rsv-xxx-prod', 'rsv-yyy-prod', 'rsv-zzz-prod')

#Automation Accounts used Connection
Connect-AzAccount -Identity
#Az Subscription Connection..
Get-AzSubscription
Set-AzContext -Subscription "Production"
Register-AzResourceProvider -ProviderNamespace "Microsoft.RecoveryServices" -ErrorAction SilentlyContinue

 # Start array loop team, Resource Group, Recovery Service Vault
for ($i=0; $i -lt $team.Length; $i++) {
Write-Output 'Team: '$team[$i]''

  # Get Azure Resource Group and start Resource Group loop
  $RGs = Get-AzResourceGroup | ?{$_.ResourceGroupName -match $team[$i]}|select ResourceGroupName, Location, Tags 
  foreach ($rg in $RGs) 
  {

 <###################  Get Azure Resource Group in SQL in Azure VM and Start Backup Procedure   #################>
 $RG_sqlVMs = Get-AzSqlVM -ResourceGroupName $rg.ResourceGroupName | Where-Object Name -match $team[$i] 

  # Create a null auto backup config to disable IaaS backup
  foreach ($RG_sqlVM in $RG_sqlVMs) 
  { 
  Write-Output $RG_sqlVM.Name
  # Check backup status by VM Name
  switch ($RG_sqlVM.Name) {
     {$_ -match "xxx"} {
        $rsvault = Get-AzRecoveryServicesVault -ResourceGroupName $backupRG[0] -Name $backupRSVault[0]
     }
     {$_ -match "yyy"} {
        $rsvault = Get-AzRecoveryServicesVault -ResourceGroupName $backupRG[1] -Name $backupRSVault[1]
     }
     {$_ -match "zzz"} {
        $rsvault = Get-AzRecoveryServicesVault -ResourceGroupName $backupRG[2] -Name $backupRSVault[2]
     }}
     
  # Get recovery service vaults to config
  $vault1 = Get-AzRecoveryServicesVault -Name $rsvault.Name -ResourceGroupName $rsvault.ResourceGroupName 
  Set-AzRecoveryServicesBackupProperty  -Vault $vault1 -BackupStorageRedundancy GeoRedundant  
  Get-AzRecoveryServicesVault -Name $rsvault.Name -ResourceGroupName $rsvault.ResourceGroupName | Set-AzRecoveryServicesVaultContext

  $autobackupconfig = New-AzVMSqlServerAutoBackupConfig  -ResourceGroupName "rg-xxx-prod-backup" 
  Set-AzVMSqlServerExtension -AutoBackupSettings $autobackupconfig -ResourceGroupName $RG_sqlVM.ResourceGroupName -VMName $RG_sqlVM.Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 
  Register-AzRecoveryServicesBackupContainer -ResourceId $RG_sqlVM.ResourceId -BackupManagementType AzureWorkload -WorkloadType MSSQL -VaultId $vault1.ID -Force
   
  ## setting up backup policy ###
  $policy = Get-AzRecoveryServicesBackupProtectionPolicy -Name "HourlyLogBackup" -VaultId $vault1.ID 

  # Get all protectable SQL DBs found in the vault that can be backed up
  $SQLDB = Get-AzRecoveryServicesBackupProtectableItem -WorkloadType MSSQL -VaultId $vault1.ID 

  # Enable backups on all DBs not already set to backup
  foreach ($db in $SQLDB) {
    Enable-AzRecoveryServicesBackupProtection -ProtectableItem $db -Policy $policy 
  }
  # Now enable auto protection for all future DBs
  # Get the SQL Instance Items
  $SQLInstance = Get-AzRecoveryServicesBackupProtectableItem -workloadType MSSQL -ItemType SQLInstance -VaultId $vault1.ID 
  Get-AzRecoveryServicesBackupProtectableItem -workloadType MSSQL -ItemType SQLInstance -VaultId $vault1.ID 

  # Set Auto Protect for each Instance
  # This is then auto executed as a background task every 8hrs
  foreach ($instance in $SQLInstance) {
    Enable-AzRecoveryServicesBackupAutoProtection -InputItem $instance -BackupManagementType AzureWorkload -WorkloadType MSSQL -Policy $policy -VaultId $vault1.ID 
  }
  }
  }
}



