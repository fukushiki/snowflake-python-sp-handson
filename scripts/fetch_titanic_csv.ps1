$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$DataDir = Join-Path $RootDir "data"
$DatasetName = "yasserh/titanic-dataset"

New-Item -ItemType Directory -Path $DataDir -Force | Out-Null

if (-not (Get-Command kaggle -ErrorAction SilentlyContinue)) {
    throw "kaggle CLI が見つかりません。pip install kaggle を実行してください。"
}

$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
$ZipFile = Join-Path $TempDir "titanic-dataset.zip"
$ExtractDir = Join-Path $TempDir "extracted"

New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

try {
    Write-Host "Downloading dataset from Kaggle..."
    kaggle datasets download -d $DatasetName -p $TempDir -o -q | Out-Null

    $DatasetZip = Join-Path $TempDir "titanic-dataset.zip"
    if (Test-Path $DatasetZip) {
        $ZipFile = $DatasetZip
    }

    Write-Host "Extracting zip..."
    Expand-Archive -Path $ZipFile -DestinationPath $ExtractDir -Force

    $csvFiles = Get-ChildItem -Path $ExtractDir -Filter *.csv -File
    if (-not $csvFiles -or $csvFiles.Count -eq 0) {
        throw "ZIP 内に CSV が見つかりませんでした。"
    }

    foreach ($file in $csvFiles) {
        Copy-Item -Path $file.FullName -Destination $DataDir -Force
        Write-Host "Copied: $($file.Name) -> $DataDir"
    }

    Write-Host "Done. $($csvFiles.Count) file(s) copied to $DataDir"
}
finally {
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force
    }
}
