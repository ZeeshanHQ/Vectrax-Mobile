$env:JAVA_HOME = 'C:\Program Files\Java\jdk-24'
$env:ANDROID_HOME = 'C:\Android\Sdk'
$env:ANDROID_SDK_ROOT = 'C:\Android\Sdk'
$env:GRADLE_OPTS = "-Dorg.gradle.daemon=false"
$env:PATH = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:PATH"

echo "Building production release APK for Vectrax (Daemon Disabled)..."
flutter build apk --release
