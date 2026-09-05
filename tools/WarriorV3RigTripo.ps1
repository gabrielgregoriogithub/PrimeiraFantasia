param([ValidateSet('check','rig','poll-check','poll-rig','download')][string]$Action='check')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$out=Join-Path $root 'assets/characters/warrior_v3/rigged/work/tripo'
[IO.Directory]::CreateDirectory($out)|Out-Null
$raw=Join-Path $root 'assets/characters/warrior_v3/raw/Warrior_V3_RAW.glb'
$key=$env:TRIPO_API_KEY
if(-not $key){$key=[Environment]::GetEnvironmentVariable('TRIPO_API_KEY','User')}
if(-not $key){throw 'TRIPO_API_KEY NOT AVAILABLE'}
Add-Type -AssemblyName System.Net.Http
$client=[Net.Http.HttpClient]::new()
$client.Timeout=[TimeSpan]::FromSeconds(180)
$client.DefaultRequestHeaders.Authorization=[Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$key)
$base='https://openapi.tripo3d.ai/v3'
function Save($p,$v){[IO.File]::WriteAllText($p,($v|ConvertTo-Json -Depth 40),[Text.UTF8Encoding]::new($false))}
function Call($route,$data=$null){
 if($null -eq $data){$r=$client.GetAsync($base+$route).GetAwaiter().GetResult()}else{$c=[Net.Http.StringContent]::new(($data|ConvertTo-Json -Depth 10),[Text.Encoding]::UTF8,'application/json');$r=$client.PostAsync($base+$route,$c).GetAwaiter().GetResult()}
 $s=$r.Content.ReadAsStringAsync().GetAwaiter().GetResult();$j=$s|ConvertFrom-Json
 if(-not $r.IsSuccessStatusCode -or $j.code -ne 0){throw $s.Replace($key,'[REDACTED]')};return $j
}
try{
 $kind=if($Action -match 'check'){'check'}else{'rig'}
 $mp=Join-Path $out ($kind+'.json')
 if($Action -in @('check','rig')){
  if(Test-Path $mp){throw 'Metadata exists; inspect/poll rather than resubmit'}
  $up=Join-Path $out 'upload.json'
  if(-not(Test-Path $up)){
   $form=[Net.Http.MultipartFormDataContent]::new();$bytes=[Net.Http.ByteArrayContent]::new([IO.File]::ReadAllBytes($raw));$form.Add($bytes,'file','Warrior_V3_RAW.glb')
   $r=$client.PostAsync($base+'/files',$form).GetAwaiter().GetResult();$s=$r.Content.ReadAsStringAsync().GetAwaiter().GetResult();$u=$s|ConvertFrom-Json
   if(-not $r.IsSuccessStatusCode -or $u.code -ne 0){throw $s.Replace($key,'[REDACTED]')}
   Save $up @{file_token=$u.data.file_token;source='raw/Warrior_V3_RAW.glb';sha256=(Get-FileHash $raw).Hash;time=[DateTime]::UtcNow.ToString('o')}
  }
  $u=Get-Content $up -Raw|ConvertFrom-Json
  $params=@{input=$u.file_token};$route='/animations/rig-check'
  if($Action -eq 'rig'){
   $check=Get-Content (Join-Path $out 'check.json') -Raw|ConvertFrom-Json
   if($check.task.data.status -ne 'success' -or -not $check.task.data.output.riggable){throw 'Rig check not passed'}
   $route='/animations/rig';$params.model='v1.0-20240301';$params.rig_type='biped';$params.spec='mixamo';$params.out_format='glb'
  }
  $m=@{endpoint=$route;parameters=$params;source_sha256=$u.sha256;balance_before=(Call '/account/balance').data;time=[DateTime]::UtcNow.ToString('o');status='pending'}
  Save $mp $m
  $r=Call $route $params;$m.task_id=$r.data.task_id;$m.status='submitted';Save $mp $m
  Write-Output ($kind+' task_id='+$m.task_id)
 }else{
  $m=Get-Content $mp -Raw|ConvertFrom-Json;$t=Call ('/tasks/'+$m.task_id)
  $m|Add-Member -Force NoteProperty task $t;$m|Add-Member -Force NoteProperty balance_after ((Call '/account/balance').data);Save $mp $m
  Write-Output ($t.data|ConvertTo-Json -Depth 10)
  if($Action -eq 'download' -and $t.data.status -eq 'success'){
   $target=Join-Path $out 'Warrior_V3_Tripo_Rig.glb';if(Test-Path $target){throw 'Output exists'}
   $dl=[Net.Http.HttpClient]::new();$data=$dl.GetByteArrayAsync($t.data.output.model_url).GetAwaiter().GetResult();$dl.Dispose()
   if([Text.Encoding]::ASCII.GetString($data,0,4) -ne 'glTF'){throw 'Not GLB'};[IO.File]::WriteAllBytes($target,$data)
  }
 }
}finally{$client.Dispose();$key=$null}
