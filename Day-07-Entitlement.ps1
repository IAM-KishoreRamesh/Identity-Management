Import-Module Microsoft.Graph.Identity.Governance
Import-Module Microsoft.Graph.Groups

# Step 1: Create the Entitlement Management Catalog
# In Entra ID, a Catalog is a container for resources and access packages.
# It serves as a delegation boundary, similar to Service Categories in OIM.
Write-Host "1. Provisioning Resource Catalog..."
# Used Splatting to define the parameter values for better readability
$CatalogParam = @{
 DisplayName = "Engineering Resources"
 Description = "Self-Service catalog for Engineering"
 State = "published"
}
$Catalog = New-MgEntitlementManagementCatalog @CatalogParam
Write-Host "SUCCESS: catalog Created -> $($Catalog.Id)"

# Step 2: Create the Security Group
# This group acts as the "Resource" that users will eventually gain access to.
Write-Host "2. Provisioning Assigned Security Group..."
$GroupParams = @{
 DisplayName = "SG-Project-Contributors"
 MailEnabled = $false
 SecurityEnabled = $true
 MailNickname  = "SG-Project"
}
$ProjectGroup = New-MgGroup @GroupParams
Write-Host "SUCCESS: Assigned Group Created -> $($ProjectGroup.Id)"

# Step 3: Create the Access Package
# An Access Package is the "Requestable Item" (similar to an OIM Role or Request Template).
# It bundles resources together with specific policies for access.
Write-Host "3. Provisioning Access Package..."
$PackageParam = @{
    displayName = "Project Alpha Onboarding"
    description = "Grants contributor access to Project Alpha."
    isHidden = $false
    catalog = @{
        id = $Catalog.Id
    }
}
$Package = New-MgEntitlementManagementAccessPackage -BodyParameter $PackageParam
Write-Host "SUCCESS: Access Package Created -> $($Package.Id)" -ForegroundColor Green