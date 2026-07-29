$env:JAVA_HOME = 'C:\Program Files\Java\jdk-24'
$env:ANDROID_HOME = 'C:\Android\Sdk'
$env:ANDROID_SDK_ROOT = 'C:\Android\Sdk'
$env:PATH = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:PATH"

echo "Launching Supa-app on V2204..."
echo "Note: The first build might take a few minutes."

$deviceId = (adb devices | Select-String -Pattern "192\.168\." | ForEach-Object { $_.Line.Split("`t")[0] })
if ($deviceId) {
    echo "Found wireless device: $deviceId"
    flutter run -d $deviceId --no-pub
} else {
    echo "Wireless device not found. Defaulting to general run..."
    flutter run --no-pub
}
