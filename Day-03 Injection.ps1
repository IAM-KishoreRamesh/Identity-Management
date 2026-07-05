# [SANITIZED ON 2026-07-05] SECURITY AUDIT: Hardcoded tenant IDs, credentials, and user emails replaced with generic placeholders for public repo.
<#
.SYNOPSIS
    Automates the provisioning of Azure AD (Entra ID) users from a CSV source.

.DESCRIPTION
    This script reads user metadata from a specified CSV file, authenticates via Microsoft Graph,
    and performs an "upsert" operation: updating existing users or provisioning new ones.
    and creates user accounts with a predefined password profile. It includes basic error handling
    and a post-deployment verification count.

.NOTES
    File Name: Day-03 Injection.ps1
    Requires: Microsoft.Graph.Users module.
#>

# 1. DEFINE SOURCE AND PREREQUISITES ##############################################################

# Define the full path to the CSV file containing user data.
$csvPath = "D:\Azure\Azure Governance Framework\Clean_GCC_Users.csv"

# Verify that the specified CSV file exists. If not, an error is displayed, and the script exits.
if (-Not (Test-Path $csvPath)) {
    Write-Host "FATAL ERROR: CSV file not found at $csvPath. Halting execution." -ForegroundColor Red
    return
}

# 2. LOAD MODULES & AUTHENTICATE ##################################################################

# 2. LOAD MODULES & AUTHENTICATE ##################################################################

# 1st: Explicitly import the modules to lock the correct .NET assemblies into memory
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.Users -ErrorAction Stop
Write-Host "Initiating 64-bit Authentication..." -ForegroundColor Cyan

# 2nd: Connect using Device Code to guarantee token capture in the VS Code terminal
Connect-MgGraph -Scopes "User.ReadWrite.All" -TenantId "<YOUR_TENANT_NAME>.onmicrosoft.com" 

# 3. PARSE DATA AND DEFINE DEFAULTS
$users = Import-Csv -Path $csvPath

# Default password configuration for new accounts
$PasswordProfile = @{
    Password = '<Your_TEMP_PASSWORD'
    ForceChangePasswordNextSignIn = $true
}

# 4. EXECUTE SYNCHRONIZATION (UPSERT LOGIC) #######################################################
Write-Host "Starting Identity Synchronization Loop..." -ForegroundColor Cyan

# Iterate through each user record in the imported CSV data.
foreach ($user in $users) {
    # Extract the UserPrincipalName from the current CSV user record.
    $upn = $user.UserPrincipalName
    try {
        # Attempt to retrieve an existing user from Azure AD (Entra ID) using their UPN.
        # -ErrorAction SilentlyContinue suppresses errors if the user is not found, allowing the script to proceed.
        $existingUser = Get-MgUser -UserId $upn -ErrorAction SilentlyContinue

        # ---------------------------------------------------------
        # OPTION A: UPDATE EXISTING USER
        # ---------------------------------------------------------
        # If $existingUser is not null, a match was found, and the user already exists.
        if ($existingUser) {
            Write-Host "MATCH FOUND: Updating $upn..." -ForegroundColor Yellow
            
            # Construct the update payload (Splatting Hash Table).
            # Note: UsageLocation defaults to 'IN' if the CSV field is empty.
            $updateParams = @{
                Department   = $user.Department
                JobTitle     = $user."Job Title"
                EmployeeId   = $user."EmployeeID (Custom)"
                CompanyName  = $user."Company"
                UsageLocation = if ([string]::IsNullOrWhiteSpace($user.UsageLocation)) { "IN" } else { $user.UsageLocation }
            }

            # Apply the updates to the existing user's profile using a Graph PATCH request.
            Update-MgUser -UserId $upn @updateParams
            Write-Host "SUCCESS: Profile synced for $upn" -ForegroundColor Green
        }
        # ---------------------------------------------------------
        # OPTION B: PROVISION NEW USER
        # ---------------------------------------------------------
        # If $existingUser is null, no match was found, and a new user needs to be provisioned.
        else {
            Write-Host "NO MATCH: Provisioning $upn..." -ForegroundColor Cyan
            
            # Define the core required properties for a new user
            $newUser = @{
                AccountEnabled   = $true
                DisplayName      = $user.DisplayName
                UserPrincipalName = $upn
                MailNickname     = ($upn).Split('@')[0] # Standard practice to use UPN prefix
                PasswordProfile  = $PasswordProfile # Assign the predefined temporary password profile.
            }

            # Conditionally add optional properties only if they contain data to avoid Graph validation errors
            # This prevents sending empty strings to Graph for properties that expect specific formats or non-null values.
            if (-not [string]::IsNullOrWhiteSpace($user.Department)) { $newUser.Department = $user.Department }
            if (-not [string]::IsNullOrWhiteSpace($user."Job Title")) { $newUser.JobTitle = $user."Job Title" }
            if (-not [string]::IsNullOrWhiteSpace($user."EmployeeID (Custom)")) { $newUser.EmployeeId = $user."EmployeeID (Custom)" }
            # Set UsageLocation, defaulting to 'IN' if the CSV field is empty.
            $newUser.UsageLocation = if ([string]::IsNullOrWhiteSpace($user.UsageLocation)) { "IN" } else { $user.UsageLocation }

            # Create the user using the splatted hash table
            New-MgUser @newUser -ErrorAction Stop
            Write-Host "SUCCESS: New user provisioned: $upn" -ForegroundColor Green
        }
    }
    catch {
        # Catch any errors that occur during the processing of a specific user and display an error message.
        Write-Host "ERROR: Processing failed for $upn -> $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 5. VERIFY #######################################################################################
Write-Host "Deployment Complete. Listing users created today..." -ForegroundColor Cyan

# Graph API requires date filters to be in ISO 8601 UTC format (e.g., "yyyy-MM-ddTHH:mm:ssZ").
# This line calculates the start of the current day in Universal Coordinated Time (UTC)
# to filter for users created since the beginning of today.
$todayIso = (Get-Date).Date.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
Get-MgUser -Filter "createdDateTime ge $todayIso" -All | Select-Object DisplayName, UserPrincipalName, CreatedDateTime
