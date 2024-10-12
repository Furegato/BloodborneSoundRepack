if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
{  
  $arguments = "& '" +$myinvocation.mycommand.definition + "'"
  Start-Process powershell -Verb runAs -ArgumentList $arguments
  Break
}


Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process

# Load required .NET assemblies for Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Get the current script directory
$currentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Current Execution Directory is: $currentDir"

# Define the path to test
#$currentDir = ""  # Replace this with your actual path

# Function to check if a path is valid
function Test-PathValidity {
    param(
        [string]$path
    )

    # Check if the path is null, empty, or whitespace
    if ([string]::IsNullOrWhiteSpace($path)) {
        Write-Host "Path is null, empty, or whitespace."
        return $false
    }

    # Check if the path contains invalid characters
    $invalidChars = [System.IO.Path]::GetInvalidPathChars()
    if ($path.IndexOfAny($invalidChars) -ne -1) {
        Write-Host "The path contains invalid characters."
        return $false
    }

    # Check if the path exists
    if (-not (Test-Path $path)) {
        Write-Host "The path does not exist."
        return $false
    }

    # If all checks pass, the path is valid
    return $true
}

# Test if $currentDir is valid
if (-not (Test-PathValidity $currentDir)) {
    # If invalid, set $currentDir to C:\
    Write-Host "Setting default path to C:\"
    $currentDir = "C:\"
} else {
    Write-Host "Path is valid: $currentDir"
}

# Function to select the folder containing .fsb files
function Select-FsbFolder {
    $fsb_folder_dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $fsb_folder_dialog.Description = "Select the folder containing .fsb files"
    $fsb_folder_dialog.SelectedPath = $currentDir  # Set default folder to current script directory
    if ($fsb_folder_dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $fsb_folder_dialog.SelectedPath
    } else {
        Write-Host "No folder selected."
        exit
    }
}

# Check for .fsb files in the selected folder
function Check-FsbFiles {
    param (
        [string]$folder
    )
    if (-not (Get-ChildItem -Path "$folder\*.fsb" -ErrorAction SilentlyContinue)) {
        $errorMessage = "No .fsb files found in the selected folder. Please try running the script again."
        Write-Host $errorMessage  # Print error message to terminal
        [System.Windows.Forms.MessageBox]::Show(
            $errorMessage,
            "Warning",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        exit  # Stop the script if no .fsb files are found
    }
}

$cores = (Get-WmiObject -Class Win32_Processor).NumberOfCores
Write-Host "Number of processor cores in your PC: $cores"
Write-Host ""

# Function to get max concurrent jobs from user
function Get-MaxConcurrentJobs {
    $inputBox = New-Object System.Windows.Forms.Form
    $inputBox.Text = "Max Concurrent Jobs"
    $inputBox.Width = 300
    $inputBox.Height = 150
    $inputBox.StartPosition = "CenterScreen"

    # Ensure the window is always in focus
    $inputBox.TopMost = $true

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Enter maximum number of concurrent jobs:"
    $label.AutoSize = $true
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $inputBox.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10, 50)
    $textBox.Width = 260
    $textBox.Text = "$cores"  # Suggested default value
    $inputBox.Controls.Add($textBox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Location = New-Object System.Drawing.Point(200, 80)
    $okButton.Add_Click({
        $inputBox.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $inputBox.Close()
    })
    $inputBox.Controls.Add($okButton)

    # Show the dialog and wait for user input
    $dialogResult = $inputBox.ShowDialog()

    # Validate input and return
    $maxJobs = 0
    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK -and [int]::TryParse($textBox.Text, [ref]$maxJobs) -and $maxJobs -gt 0) {
        return $maxJobs
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Please enter a valid positive number.",
            "Invalid Input",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        exit
    }
}

# Select the FSB folder
$fsb_folder = Select-FsbFolder
Write-Host "Selected FSB folder: $fsb_folder"
Write-Host ""

# Check for .fsb files in the selected folder
Check-FsbFiles -folder $fsb_folder

# Define the expected path for the vgmstream-cli.exe executable
$vgmstream_cli_path = Join-Path "$currentDir" "\vgmstream-win64\vgmstream-cli.exe"

# Check if the vgmstream-cli.exe file exists in the current directory
if (Test-Path $vgmstream_cli_path) {
    $vgmstream_cli = $vgmstream_cli_path
    Write-Host "Found vgmstream-cli at: $vgmstream_cli"
} else {
    # If the file is not found, prompt the user to select it
    $vgmstream_cli_dialog = New-Object System.Windows.Forms.OpenFileDialog
    $vgmstream_cli_dialog.Title = "Select vgmstream-cli.exe"
    $vgmstream_cli_dialog.Filter = "Executable Files (vgmstream-cli.exe)|vgmstream-cli.exe"
    $vgmstream_cli_dialog.InitialDirectory = "$currentDir"

    if ($vgmstream_cli_dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $vgmstream_cli = $vgmstream_cli_dialog.FileName
        Write-Host "Selected vgmstream-cli path: $vgmstream_cli"
    } else {
        Write-Host "vgmstream-cli.exe not selected."
        exit
    }
}

Write-Host "Selected vgmstream-cli path: $vgmstream_cli"
Write-Host ""

# Define the expected path for the FMOD Bank Tool executable
$FmodBankToolPath = Join-Path "$currentDir" "\Fmod\fsbankcl.exe"

# Check if the FMOD Bank Tool executable exists in the specified folder
if (Test-Path $FmodBankToolPath) {
    Write-Host "Found FMOD Bank Tool at: $FmodBankToolPath"
} else {
    # If the file is not found, prompt the user to select it
    $FmodBankToolDialog = [System.Windows.Forms.OpenFileDialog]::new()
    $FmodBankToolDialog.Title = "Select the FMOD Bank Tool executable fsbankcl.exe"
    $FmodBankToolDialog.Filter = "Executable Files (fsbankcl.exe)|fsbankcl.exe"

    if ($FmodBankToolDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $FmodBankToolPath = $FmodBankToolDialog.FileName
        Write-Host "Selected FMOD Bank Tool path: $FmodBankToolPath"
    } else {
        Write-Host "No executable selected. Terminating."
        exit
    }
}

Write-Host "Selected FMod Bank Tool path: $FmodBankToolPath"
Write-Host ""

# Get max concurrent jobs from user
$maxConcurrentJobs = Get-MaxConcurrentJobs
Write-Host "Max Concurrent Jobs: $maxConcurrentJobs"
Write-Host ""

# Create a "converted" folder inside the fsb folder if it doesn't exist
$converted_folder = Join-Path $fsb_folder "converted"
if (-not (Test-Path -Path $converted_folder)) {
    New-Item -Path $converted_folder -ItemType Directory
}

# Function to select folder with a message in the dialog box
$OGGinputPath = $converted_folder
Write-Host "Created OGG input folder: $OGGinputPath"
Write-Host ""

# Create a "repacked" folder inside the fsb folder if it doesn't exist
$FSBoutputPath = Join-Path $fsb_folder "repacked"
if (-not (Test-Path -Path $FSBoutputPath)) {
    New-Item -Path $FSBoutputPath -ItemType Directory
}
Write-Host "FSB Final output folder: $FSBoutputPath"
Write-Host ""

# Load required .NET assemblies for Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Define the custom dialog function
function Show-CustomDialog_Conflict {
    # Create the custom form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "File Conflict"
    $form.Size = New-Object System.Drawing.Size(400, 150)
    $form.StartPosition = "CenterScreen"
    $form.TopMost = $true

    # Label with the message
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "There are already .fsb files in the output folder. What would you like to do?"
    $label.AutoSize = $true
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $form.Controls.Add($label)

    # Skip button
    $skipButton = New-Object System.Windows.Forms.Button
    $skipButton.Text = "Skip Existing"
    $skipButton.Width = 100
    $skipButton.Location = New-Object System.Drawing.Point(10, 70)
    $form.Controls.Add($skipButton)

    # Overwrite button
    $overwriteButton = New-Object System.Windows.Forms.Button
    $overwriteButton.Text = "Overwrite All"
    $overwriteButton.Width = 100
    $overwriteButton.Location = New-Object System.Drawing.Point(130, 70)
    $form.Controls.Add($overwriteButton)

    # Re-Select button
    $reselectButton = New-Object System.Windows.Forms.Button
    $reselectButton.Text = "Re-Select Folder"
    $reselectButton.Width = 100
    $reselectButton.Location = New-Object System.Drawing.Point(250, 70)
    $form.Controls.Add($reselectButton)

    # Event handlers for the buttons
    $skipButton.Add_Click({
        $form.Tag = "Skip"
        $form.Close()
    })

    $overwriteButton.Add_Click({
        $form.Tag = "Overwrite"
        $form.Close()
    })

    $reselectButton.Add_Click({
        $form.Tag = "Re-Select"
        $form.Close()
    })

    # Show the dialog
    $form.ShowDialog() | Out-Null

    return $form.Tag
}


# Variable to track if the user chooses to skip
$skipFlag = $false

# Variable to track if the user chooses to skip
$skipFlag = $false
$reselectFlag = $true  # Flag to control re-selection

while ($reselectFlag) {
    # Check if there are existing .fsb files in the selected output path
    if (Test-Path "$FSBoutputPath\*.fsb") {
        # Show custom dialog with options Skip, Overwrite, Re-Select
        $userChoice = Show-CustomDialog_Conflict
        Write-Host $userChoice

        # Act based on user's choice    
        switch ($userChoice) {
            "Skip" {
                Write-Host "`nYou chose to skip overwriting the existing files."
                # Set the skip flag to true
                $skipFlag = $true
                $reselectFlag = $false  # Exit the loop
            }
            "Overwrite" {
                Write-Host "`nYou chose to overwrite the existing files."
                $reselectFlag = $false  # Exit the loop, continue with the script
            }
            "Re-Select" {
                Write-Host "`nYou chose to re-select the output folder."

                $FSBoutputPathDialog = New-Object System.Windows.Forms.FolderBrowserDialog
                $FSBoutputPathDialog.Description = "Select the output folder for repacked files"
                $FSBoutputPathDialog.SelectedPath = $FSBoutputPath
                if ($FSBoutputPathDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $FSBoutputPath = $FSBoutputPathDialog.SelectedPath
                    Write-Host "New output folder selected: $FSBoutputPath"
                } else {
                    Write-Host "No folder selected. Terminating."
                    exit
                }
            }
            default {
                Write-Host "No valid option selected. Terminating."
                exit
            }
        }
    } else {
        $reselectFlag = $false  # Exit the loop if no existing .fsb files are found
    }
}


# Create a fbs temporary folder inside the fsb folder if it doesn't exist
$FSBoutputPathTemp = Join-Path $FSBoutputPath "temp"
if (-not (Test-Path -Path $FSBoutputPathTemp)) {
    New-Item -Path $FSBoutputPathTemp -ItemType Directory
}
else {
    # Delete all files in the folder
    Remove-Item -Path "$FSBoutputPathTemp\*" -Force
}
Write-Host "FSB Temp output folder: $FSBoutputPathTemp"
Write-Host ""

# Create Temporary Data Cache Path (based on the output path)
$DataCache = Join-Path $FSBoutputPath "cache"
if (-not (Test-Path -Path $DataCache)) {
    New-Item -Path $DataCache -ItemType Directory
}
Write-Host "FMOD Temporary Cache folder: $DataCache"
Write-Host ""

# Record the start time
$startTime = Get-Date
Write-Host ""
Write-Host "PROCESSING FILES..."
Write-Host ""


# Job queue
$jobs = @()

# Create an ArrayList for job management
$jobs = New-Object System.Collections.ArrayList

# Files to process
$fsbFiles = Get-ChildItem -Path "$fsb_folder\*.fsb"

# Job index tracker
$fileIndex = 0

# Function to start new jobs
function Start-NewJob {
    param (
        $fsbFile
    )
    $baseFileName = [System.IO.Path]::GetFileNameWithoutExtension($fsbFile)
    $outputFSB = Join-Path $FSBoutputPath ($baseFileName + ".fsb")

    # Check if the output file exists and skip if the skipFlag is true
    if ($skipFlag -and (Test-Path $outputFSB)) {
        Write-Host "Skipping $fsbFile because it already exists in the output folder."
        return  # Skip starting the job
    }

    $job = Start-Job -ScriptBlock {
        param ($vgmstream_cli, $fsbFile, $oggenc2_exe, $converted_folder, $baseFileName, $FSBoutputPath, $DataCache, $FmodBankToolPath, $FSBoutputPathTemp)
        
        Write-Host "Processing $fsbFile..."

        # Create the base folder inside "converted" with the .fsb file name
        $baseFolder = Join-Path $converted_folder "$baseFileName"
        if (-Not (Test-Path $baseFolder)) {
            New-Item -ItemType Directory -Path $baseFolder -Force
        }

        # Run vgmstream-cli to get JSON output
        $output = & "$vgmstream_cli" -S 0 $fsbFile -I -m

        # Convert output to JSON array
        $jsonObjects = $output | ConvertFrom-Json

        # Iterate over each subsong (index)
        foreach ($json in $jsonObjects) {
            $index = $json.streamInfo.index
            $name = $json.streamInfo.name

            # Pad the index with leading zeros to make it 5 digits
            $paddedIndex = $index.ToString().PadLeft(5, '0')

            # Create subfolder for each index inside the base folder
            $subFolder = Join-Path $baseFolder "$paddedIndex"
            if (-Not (Test-Path $subFolder)) {
                New-Item -ItemType Directory -Path $subFolder
            }

            # Construct the output wav file path
            $wavFile = Join-Path $subFolder "$name.wav"
            
            # Execute the vgmstream command
            $vgmstreamCommand = "& `"$vgmstream_cli`" -s $index `"$fsbFile`" -o `"$wavFile`""
            Write-Host "Executing VGMStream SubJob Command: $vgmstreamCommand"
            Write-Host ""
            Invoke-Expression $vgmstreamCommand | Out-Null

            Write-Host "Successfully Extracted $wavFile"
            Write-Host ""
            Write-Host ""
        }

        # Repack OGG to FSB
        $outputFSB = Join-Path $FSBoutputPathTemp ($baseFileName + ".fsb")
        $finalCommand = "& `"$FmodBankToolPath`" -o `"$outputFSB`" `"$baseFolder`" -format vorbis -quality 50 -recursive -verbosity 0 -cache_dir `"$DataCache`""
        Write-Host "Executing Job Fmod Command: $finalCommand"
        Write-Host ""
        Invoke-Expression $finalCommand

        # Move all files from the source folder to the destination folder      
        Move-Item -Path "$outputFSB" -Destination "$FSBoutputPath" -Force

        Write-Host "Successfully Repacked: $baseFileName to $baseFolder.fsb"
        Write-Host ""
        Write-Host ""

        # Delete the wav file after conversion
        Remove-Item -Path $baseFolder -Recurse -Force
        Write-Host "Deleted temporary $baseFolder"

    } -ArgumentList $vgmstream_cli, $fsbFile, $oggenc2_exe, $converted_folder, $baseFileName, $FSBoutputPath, $DataCache, $FmodBankToolPath, $FSBoutputPathTemp

    [void]$jobs.Add($job)
}


# Main job loop
while ($fileIndex -lt $fsbFiles.Count -or $jobs.Count -gt 0) {
    # Start jobs up to the max concurrent limit
    while ($jobs.Count -lt $maxConcurrentJobs -and $fileIndex -lt $fsbFiles.Count) {
        Start-NewJob $fsbFiles[$fileIndex]
        $fileIndex++
    }

    # Wait for any job to complete
    $completedJobs = @()
    $jobs | ForEach-Object {
        if ($_ | Wait-Job -Timeout 1 -ErrorAction SilentlyContinue) {
            $completedJobs += $_
        }
    }

    # Remove completed jobs from the main list and report completion
    foreach ($completedJob in $completedJobs) {
        $jobs.Remove($completedJob) | Out-Null
        $jobResult = Receive-Job -Job $completedJob
        Write-Host "Job completed: $($completedJob.Id)"
        Write-Host ""
    }
}

# Clean up after all jobs are completed
Remove-Item -Path "$DataCache" -Recurse -Force
Remove-Item -Path "$converted_folder" -Recurse -Force
Remove-Item -Path "$FSBoutputPathTemp" -Recurse -Force

# Record the end time
$endTime = Get-Date
$duration = $endTime - $startTime

# Print completion message to the terminal
Write-Host `n`n"REPACKING COMPLETED! The repacked files can be found in: $FSBoutputPath"
Write-Host ""
Write-Host "Total time taken: $duration"
Write-Host ""
Write-Host "You can now close this window."
Write-Host ""

Start-Process explorer.exe -ArgumentList $FSBoutputPath

# Create a new form to act as the owner of the message box
$ownerForm = New-Object System.Windows.Forms.Form
$ownerForm.StartPosition = "CenterScreen"
$ownerForm.TopMost = $true
$ownerForm.ShowInTaskbar = $false
$ownerForm.Size = New-Object System.Drawing.Size(0, 0)  # Invisible size

# Display completion message with the path of converted files and duration
[System.Windows.Forms.MessageBox]::Show(
    $ownerForm,
    "Repacking is completed! The repacked files can be found in:`n$FSBoutputPath`nTotal time taken: $duration",
    "Repacking Completed",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
)