$bytes = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$env:ENCRYPTION_KEY = [Convert]::ToBase64String($bytes)

docker compose up -d db