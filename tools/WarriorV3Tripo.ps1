param(
    [ValidateSet('submit','poll','download')][string]$Action = 'poll',
    [ValidateRange(1,3)][int]$Candidate = 1,
    [int]$Seed = 2026090501,
    [int]$FaceLimit = 10000,
    [ValidateSet('P2-20260801','P1-20260311')][string]$Model = 'P2-20260801'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$asset = Join-Path $root 'assets/characters/warrior_v3'
$out = Join-Path $asset 'raw/candidates'
[IO.Directory]::CreateDirectory($out) | Out-Null
$name = 'candidate_{0:D2}' -f $Candidate
$metaPath = Join-Path $out ($name+'.json')
$base = 'https://openapi.tripo3d.ai/v3'
$key = $env:TRIPO_API_KEY
if ([string]::IsNullOrWhiteSpace($key)) { $key = [Environment]::GetEnvironmentVariable('TRIPO_API_KEY','User') }
if ([string]::IsNullOrWhiteSpace($key)) { throw 'TRIPO_API_KEY: NOT AVAILABLE' }
Add-Type -AssemblyName System.Net.Http
$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds(180)
$client.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$key)
function Save-Json($path,$obj) { [IO.File]::WriteAllText($path,($obj | ConvertTo-Json -Depth 40),[Text.UTF8Encoding]::new($false)) }
function Api-Get($route) {
    $response = $client.GetAsync($base+$route).GetAwaiter().GetResult()
    $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    if (-not $response.IsSuccessStatusCode) { throw ('HTTP '+[int]$response.StatusCode+': '+$body.Replace($key,'[REDACTED]')) }
    $j=$body | ConvertFrom-Json
    if ($j.code -ne 0) { throw ('API error: '+$body.Replace($key,'[REDACTED]')) }
    return $j
}
try {
    if ($Action -eq 'submit') {
        if (Test-Path -LiteralPath $metaPath) { throw 'Candidate metadata already exists. Poll or inspect it; never resubmit automatically.' }
        $balance = Api-Get '/account/balance'
        if ($balance.data.balance -le 0) { throw 'No credits available' }
        $sources=@()
        $inputs=@()
        $cachePath=Join-Path $out 'source_uploads.json'
        $cache=@()
        if (Test-Path -LiteralPath $cachePath) { $cache=Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json }
        foreach ($view in @('front','left','back','right')) {
            $relative='concept/warrior_v3_'+$view+'.png'
            $path=Join-Path $asset $relative
            $hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
            $found=$cache | Where-Object { $_.view -eq $view -and $_.sha256 -eq $hash } | Select-Object -First 1
            if ($null -eq $found) {
                $form=[System.Net.Http.MultipartFormDataContent]::new()
                $bytes=[System.Net.Http.ByteArrayContent]::new([IO.File]::ReadAllBytes($path))
                $bytes.Headers.ContentType=[System.Net.Http.Headers.MediaTypeHeaderValue]::new('image/png')
                $form.Add($bytes,'file',[IO.Path]::GetFileName($path))
                $response=$client.PostAsync($base+'/files',$form).GetAwaiter().GetResult()
                $body=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                $form.Dispose()
                $uploaded=$body | ConvertFrom-Json
                if (-not $response.IsSuccessStatusCode -or $uploaded.code -ne 0) { throw ('Upload failed: '+$body.Replace($key,'[REDACTED]')) }
                $found=[pscustomobject]@{view=$view;path=$relative;sha256=$hash;file_token=$uploaded.data.file_token;uploaded_at=[DateTime]::UtcNow.ToString('o')}
                $cache+= $found
                Save-Json $cachePath $cache
            }
            if ($found.file_token -isnot [string]) { throw 'Expected one string file_token per view' }
            $sources+= $found
            $inputs+= @{ $view=$found.file_token }
            Write-Output ('Input ready: '+$view)
        }
        $params=[ordered]@{inputs=$inputs;model=$Model;model_seed=$Seed;texture_seed=$Seed;face_limit=$FaceLimit;texture=$true;pbr=$false;texture_quality='standard';texture_alignment='original_image';export_uv=$true}
        if ($Model -eq 'P2-20260801') { $params.quad=$true }
        $meta=[ordered]@{candidate=$name;api_base=$base;endpoint='/generation/multiview-to-model';model=$params.model;seed=$Seed;parameters=$params;source_inputs=$sources;task_id=$null;credits=$null;balance_before=$balance.data;generated_urls=$null;created_local_at=[DateTime]::UtcNow.ToString('o');status='submission_pending';documentation='https://developers.tripo3d.ai/en/docs/generation-multiview-to-model/p'}
        Save-Json $metaPath $meta
        $content=[System.Net.Http.StringContent]::new(($params | ConvertTo-Json -Depth 10),[Text.Encoding]::UTF8,'application/json')
        $response=$client.PostAsync($base+'/generation/multiview-to-model',$content).GetAwaiter().GetResult()
        $body=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $result=$body | ConvertFrom-Json
        $meta.submission_response=$result
        if (-not $response.IsSuccessStatusCode -or $result.code -ne 0) {
            $meta.status='submission_rejected'; Save-Json $metaPath $meta
            throw ('Submission rejected: '+$body.Replace($key,'[REDACTED]'))
        }
        $meta.task_id=$result.data.task_id
        $meta.status='submitted'
        Save-Json $metaPath $meta
        Write-Output ('Submitted '+$name+' task_id='+$meta.task_id)
    } else {
        $meta=Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
        if (-not $meta.task_id) { throw 'No task ID; inspect submission metadata before any retry.' }
        $task=Api-Get ('/tasks/'+$meta.task_id)
        $meta | Add-Member -Force NoteProperty task_response $task
        $meta | Add-Member -Force NoteProperty last_polled_at ([DateTime]::UtcNow.ToString('o'))
        $meta.status=$task.data.status
        $meta.credits=$task.data.credits_consumed
        $meta.generated_urls=$task.data.output
        Save-Json $metaPath $meta
        Write-Output ($name+' status='+$meta.status+' progress='+$task.data.progress+' credits='+$meta.credits)
        if ($Action -eq 'download' -and $meta.status -eq 'success') {
            $url=$task.data.output.model_url
            if (-not $url) { Write-Output ($task.data.output | ConvertTo-Json -Depth 10); throw 'Model URL missing' }
            $extension=[IO.Path]::GetExtension(([Uri]$url).AbsolutePath).ToLowerInvariant()
            if ($extension -notin @('.glb','.fbx')) { throw ('Unexpected output extension: '+$extension) }
            $target=Join-Path $out ('Warrior_V3_'+$name+$extension)
            if (Test-Path -LiteralPath $target) { throw 'GLB already exists; will not overwrite candidate.' }
            $download=[System.Net.Http.HttpClient]::new()
            $download.Timeout=[TimeSpan]::FromMinutes(5)
            $data=$download.GetByteArrayAsync($url).GetAwaiter().GetResult()
            $download.Dispose()
            if ($extension -eq '.glb' -and [Text.Encoding]::ASCII.GetString($data,0,4) -ne 'glTF') { throw 'Downloaded output is not GLB' }
            if ($extension -eq '.fbx' -and [Text.Encoding]::ASCII.GetString($data,0,18) -ne 'Kaydara FBX Binary') { throw 'Downloaded output is not binary FBX' }
            [IO.File]::WriteAllBytes($target,$data)
            $meta | Add-Member -Force NoteProperty downloaded_at ([DateTime]::UtcNow.ToString('o'))
            $meta | Add-Member -Force NoteProperty source_model_format $extension
            $meta | Add-Member -Force NoteProperty source_model_sha256 ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash)
            $meta | Add-Member -Force NoteProperty source_model_bytes $data.Length
            $meta | Add-Member -Force NoteProperty balance_after ((Api-Get '/account/balance').data)
            Save-Json $metaPath $meta
            Write-Output ('Downloaded '+$target+' bytes='+$data.Length)
        }
    }
} finally { $client.Dispose(); $key=$null }
