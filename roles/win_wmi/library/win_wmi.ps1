#!powershell

# Copyright: (c) 2019, tuccimon
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        namespace = @{ type = "str"; required = $true }
        class = @{ type = "str"; }
        property = @{ type = "str"; }
        data = @{ type = "str"; }
        type = @{ type = "str"; }
        recursive = @{ type = "bool"; default = $true }
        state = @{ type = "str"; default = "present"; choices = @("absent", "present") }
    }

    required_together = @(
        @("data", "type")
    )

    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$namespace = $module.Params.namespace
$class = $module.Params.class
$property = $module.Params.property
$data = $module.Params.data
$recursive = $module.Params.recursive
$state = $module.Params.state

function Test-WmiNamespace {
    param($NamespaceName)
    (!((Get-WmiObject -Namespace root\$NamespaceName -List -ErrorAction SilentlyContinue | select -First 1) -eq $null))
}

function Create-WmiNamespace {
    [CmdletBinding()]
    param($NamespaceName)

    if (!(Test-WmiNamespace -NamespaceName $NamespaceName)) {
        $objNS = [wmiclass]'root:__Namespace'
        $objInstance = $objNS.CreateInstance()
        $objInstance.Name = $NamespaceName
        $objInstance.Put()
    }
}

function Remove-WmiNamespace {
    [CmdletBinding()]
    param($NamespaceName)
    # get the namespace | remove-namespace
}

function Test-WmiClass {
    param(
        $NamespaceName,
        $ClassName
    )
    (!((Get-WmiObject -Namespace root\$ClassName -Class $ClassName -List -ErrorAction SilentlyContinue | select -First 1) -eq $null))
}

function Get-WmiClass {
    param(
        $NamespaceName,
        $ClassName
    )
    Get-WmiObject -Namespace root\$ClassName -Class $ClassName -List -ErrorAction SilentlyContinue
}

function Create-WmiClass {
    [CmdletBinding()]
    param(
        $NamespaceName,
        $ClassName
    )

    if (!(Test-WmiClass -NamespaceName $NamespaceName -ClassName $ClassName)) {
        $objClass = New-Object System.Management.ManagementClass("root\$NamespaceName", [string]::Empty, $null)
        $objClass["__CLASS"] = $ClassName
        $objClass.Put()
    }
}

function Remove-WmiClass {
    [CmdletBinding()]
    param(
        $NamespaceName,
        $ClassName
    )
    # get the namespace | remove-namespace
}

function Get-WmiProperty {
    param(
        $NamespaceName,
        $ClassName,
        $PropertyName
    )

}

function Set-WmiProperty {
    param(
        $NamespaceName,
        $ClassName,
        $PropertyName
    )

}

function Remove-WmiProperty {
    param(
        $NamespaceName,
        $ClassName,
        $PropertyName
    )

}

function Test-DataType {
    param($TypeName)
    (!([System.Management.CimType]::$TypeName -eq $null))
}

# check if data type is not null and check if valid
if ($type -ne $null -and !(Test-DataType -TypeName $type)) {
    $module.FailJson("data type provided '$type' is not a valid WMI data type. ")
}

# check if property name is present but not class name
if ($property -ne $null -and $class -eq $null) {
    $module.FailJson("class name must be specified if property name is. ")
}

# check if data is provided but not property name
if ($data -ne $null -and $property -eq $null) {
    $module.FailJson("property name must be specified if data value is. ")
}

# check which path to go: present (create/existing) or absent (delete/non-existing)
if ($state -eq 'present') {
    # (present) ensure that full request is create or existing; recursive is implied

    # first check if namespace exists
    if (Test-WmiNamespace -NamespaceName $namespace) {
        # namespace exists, next check if class was provided
        if ($class -ne $null) {
            # check if class exists
            if (Test-WmiClass -NamespaceName $namespace -ClassName -$class) {
                # check if property was provided
                if ($property -ne $null) {
                    $objProperty = Get-WmiProperty -NamespaceName $namespace -ClassName $class -PropertyName -$property
                    # check if property was retrieved
                    if ($objProperty -ne $null) {
                        # check if name, data type, and data match what the intent is


                    }
                    else {

                    }
                }
                else {

                }
            }
            else {

            }
        }
        else {

        }
    }
    else {

    }
}
else {
    # (absent) ensure whatever needs to be removed is or ensure it's not there

}




$module.Result.changed = $changed

#-not $module.CheckMode


Exit-Json $result
