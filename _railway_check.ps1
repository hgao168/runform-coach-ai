$token = ((Get-Content "$env:USERPROFILE\.railway\config.json") | ConvertFrom-Json).user.accessToken
$r = Invoke-WebRequest "https://backboard.railway.com/graphql/v2" -Method Post -Headers @{Authorization="Bearer $token";"Content-Type"="application/json"} -Body '{"query":"{ __type(name: \"ServiceInstanceInput\") { inputFields { name } } }"}' -UseBasicParsing
($r.Content | ConvertFrom-Json).data.__type.inputFields | ForEach-Object { $_.name }
