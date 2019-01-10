param (

    [Parameter(Mandatory=$true, Position=0, HelpMessage="Search from here")]
    [ValidateNotNullOrEmpty()]
    [string] $RootPath,

    [Parameter(Mandatory=$false, HelpMessage="Create archive at this location")]
    [ValidateNotNullOrEmpty()]
    [string] $ArchivePath=".",

    [Parameter(HelpMessage="Do not do any archiving actions")]
    [Switch] $Dummy
    
)

## Init

$allProjects_dir = $RootPath
$temp_dir = "$env:temp\PSArchiver-$(Get-Date -Format 'yyyyMMddHHmmss')"

$archive_fullpath = "$ArchivePath" # may need to do some splitting and resolving here

function Write-StepHeading {
    param(
        [Parameter(Mandatory=$true, Position=1)]
        [String] $Message,

        [Parameter(Mandatory=$false)]
        [Int] $Level=1
    )

    Write-Host ""

    Switch ($Level) {
        1 { Write-Host ":: $Message" -ForegroundColor Yellow }
        2 { Write-Host "$Message" -ForegroundColor Magenta }
        default { Write-Host "$Message" }
    }

    # Write Marker for stepnotes
    $SCRIPT:isFirstNote = $true
}

function Write-StepNotes {
    param(
        [Parameter(Mandatory=$true, Position=1)]
        [String] $Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Message','ErrorMessage')]
        [String] $Stream="Message"
    )

    # Decide if should put space
    #if ($SCRIPT:isFirstNote) 
    #{ Write-Host ""; $SCRIPT:isFirstNote = $false }

    Switch ($Stream) {
        'Message'      { Write-Host " - $Message" -ForegroundColor DarkGray }
        'ErrorMessage' { Write-Host " > ERROR: $Message" -ForegroundColor Red }
    }
}

## Main

$all_project_containers = Get-ChildItem -Directory -Path $allProjects_dir
[int]$to_archive_count = 0

Write-StepHeading -Level 1 -Message "Analysing Projects Directory"

foreach ($project_container in $all_project_containers) {

    Write-StepHeading -Level 2 -Message "On: $($project_container.Name)"

    $project_container_root = $project_container.FullName
    $project_container_files = Get-ChildItem -File -Recurse -Path "$project_container_root"


    # early ticket home
    if ($(($project_container_files | Measure-Object).Count) -eq 0) {
        Write-StepNotes -Message "Empty directory"
        Write-StepNotes -Message "To archive: FALSE"

        continue
    }

    # do archiving
    $latest_file_date = ($project_container_files | Sort-Object -Descending -Property "LastWriteTime" | Select-Object -First 1).LastWriteTime
    $age_delta = $((Get-Date) - $latest_file_date).Days
    
    Write-StepNotes -Message "Days since last edit: $age_delta"

    if ($age_delta -gt 30) {
        
        $to_archive_count++
        $path_appendage = "$($latest_file_date.Year)\$($latest_file_date.Month.ToString('00'))"

        Write-StepNotes -Message "To archive: TRUE"
        
        # move to temp place, if not a dummy run
        if( -not $Dummy ) {
            Copy-Item -Recurse -Path "$($project_container.Fullname)" -Destination "$temp_dir\$path_appendage\$($project_container.Name)"
            Remove-ItemSafely -Path "$($project_container.Fullname)"
        } else {
            Write-StepNotes -Message "This is a dummy run: NO FILES WILL BE STAGED / ARCHIVED / DELETED"
        }

        Write-StepNotes -Message "Staged for archiving: $temp_dir\$path_appendage\$($project_container.Name)"

    } 
    
    else { Write-StepNotes -Message "To archive: FALSE" }

}

# Don't proceed if dummy run
if ($Dummy) {
    Write-StepHeading -Level 1 -Message "Ne Procedo - This was a dummy run"
    break
}

## Archive if necessary
if ($to_archive_count -gt 0) {

    Write-StepHeading -Level 1 -Message "Archiving Files"

    Write-StepHeading -Level 2 -Message "Calling 7za.exe"

    # zip it up
    Start-Process -Wait -FilePath ".\resource\7za.exe" -ArgumentList "a -t7z `"$archive_fullpath`" `"$temp_dir\*`" -x!7zOutput.txt" -WindowStyle Hidden -RedirectStandardOutput "$temp_dir\7zOutput.txt"

    Write-StepNotes -Message "7za finished"

}

## Clean temps
Write-StepHeading -Level 1 -Message "Housekeeping"