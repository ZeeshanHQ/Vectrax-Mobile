$jdkPath = 'C:\Program Files\Microsoft\jdk-17.0.18.8-hotspot'
$sdkPath = 'C:\Android\Sdk'
$env:JAVA_HOME = $jdkPath
$env:PATH = "$jdkPath\bin;$env:PATH"

echo "Accepting licenses..."
# Piping 10 'y' characters to handle multiple license prompts
,@("y") * 10 | & "$sdkPath\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root=$sdkPath --licenses

echo "Installing platform-tools, platforms;android-34, and build-tools;34.0.0..."
& "$sdkPath\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root=$sdkPath "platform-tools" "platforms;android-34" "build-tools;34.0.0"

echo "Configuring Flutter..."
# We need to use the virtual drive X: for flutter
& X:\bin\flutter.bat config --android-sdk $sdkPath
& X:\bin\flutter.bat doctor --android-licenses
