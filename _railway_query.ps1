$token = (Get-Content "$env:USERPROFILE\.railway\config.json" | ConvertFrom-Json).user.accessToken

# Get staging environment deployments
$query = @'
{
  "query": "mutation { serviceInstanceDeployV2(serviceId: \"d2bdff7b-1da5-4144-838b-681527e8ee8d\", environmentId: \"ac84ae0a-1117-46da-a004-acdd44027184\") }"
}
'@

$resp = Invoke-RestMethod -Uri "https://backboard.railway.com/graphql/v2" `
  -Method Post `
  -Headers @{"Authorization" = "Bearer $token"; "Content-Type" = "application/json"} `
  -Body $query

$resp | ConvertTo-Json -Depth 5
