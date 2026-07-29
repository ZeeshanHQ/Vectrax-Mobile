$env:JAVA_HOME = 'C:\Program Files\Microsoft\jdk-17.0.18.8-hotspot'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
& X:\bin\flutter.bat config --android-sdk C:\Android\Sdk
& X:\bin\flutter.bat doctor
