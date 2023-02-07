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

#Start array loop team, Resource Group, Recovery Service Vault
for ($i=0; $i -lt $team.Length; $i++) {
Write-Output 'Team: '$team[$i]''
  
#Get Azure Resource Group and start Resource Group loop
$RGs = Get-AzResourceGroup | ?{$_.ResourceGroupName -match $team[$i]}|select ResourceGroupName, Location, Tags 
  foreach ($rg in $RGs) 
  {

<###################  Get Azure Resource Group in Azure Virtual Machines and Start Backup Procedure   #################>
 $RG_VMs =  Get-AzVM -ResourceGroupName $rg.ResourceGroupName | Where-Object Name -match $team[$i]
    foreach ($VM in $RG_VMs) 
    {    
    #Check backup status by VM Name
    $status = Get-AzRecoveryServicesBackupStatus -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName -Type "AzureVM"
    if ($status.BackedUp -eq  0) 
    {     
    switch ($VM.Name)
    {
         {$_ -match "iss"} {
            $rsvault = Get-AzRecoveryServicesVault -ResourceGroupName $backupRG[0] -Name $backupRSVault[0]
         }
         {$_ -match "dss"} {
            $rsvault = Get-AzRecoveryServicesVault -ResourceGroupName $backupRG[1] -Name $backupRSVault[1]
         }
         {$_ -match "isl"} {
            $rsvault = Get-AzRecoveryServicesVault -ResourceGroupName $backupRG[2] -Name $backupRSVault[2]
         }
    }
    ###Set Keyvault Access Policy Permision####
    Get-AzRecoveryServicesVault -Name $rsvault.Name | Set-AzRecoveryServicesVaultContext

    ### setting up backup policy ###
    $policy = Get-AzRecoveryServicesBackupProtectionPolicy -Name "DefaultPolicy" -VaultId $rsvault.ID
            
    ## Enable backup Virtual Machine###
    if ($VM.Disks.Count -eq 1 ) {
     $disks = ("0","1")
     Enable-AzRecoveryServicesBackupProtection -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName -Policy $policy -InclusionDisksList $disks
     }else 
     {
     Enable-AzRecoveryServicesBackupProtection -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName -Policy $policy #-InclusionDisksList $disks
     }
    Write-Host "Applying the Policy to the Virtual Machine"
    }
   }

  }
}



