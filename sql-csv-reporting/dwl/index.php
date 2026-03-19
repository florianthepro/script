<?php
exec('php '.__DIR__.'/auto-download.php > /dev/null 2>&1 &');
$CSV_FILE='[emty]'; #csv.csv
$csvFile=__DIR__.'/'.$CSV_FILE;
$rulesFile=__DIR__.'/rules.json';
function h($s){return htmlspecialchars((string)$s,ENT_QUOTES|ENT_SUBSTITUTE,'UTF-8');}
function load_rules($path){
if(!is_readable($path))return['show_columns'=>[],'rules'=>[]];
$json=@file_get_contents($path);
$data=@json_decode($json,true);
return is_array($data)?$data:['show_columns'=>[],'rules'=>[]];
}
function parse_csv_string($csvContent){
$lines=preg_split("/\r\n|\n|\r/",$csvContent);
$rows=[];
foreach($lines as $line){
if($line==='')continue;
$rows[]=str_getcsv($line);
}
return $rows;
}
function load_csv($path){
if(!is_readable($path))return null;
return parse_csv_string(file_get_contents($path));
}
function col_index($header,$colName){
foreach($header as $i=>$h)if(strcasecmp(trim($h),trim($colName))===0)return $i;
return null;
}
function eval_text_op($value,$op,$cmp){
$value=(string)$value;
$cmp=(string)$cmp;
switch($op){
case 'wildcard':
$pattern='/^'.str_replace(['\*','\?'],['.*','.'],preg_quote($cmp,'/')).'$/i';
return @preg_match($pattern,$value)===1;
case 'contains':
return stripos($value,$cmp)!==false;
case 'equals':
return strcmp($value,$cmp)===0;
case 'starts_with':
return stripos($value,$cmp)===0;
case 'ends_with':
$len=strlen($cmp);
if($len===0)return true;
return strcasecmp(substr($value,-$len),$cmp)===0;
case 'regex':
$ok=@preg_match($cmp,$value);
return $ok===1;
case 'empty':
return trim($value)==='';
case 'empty_or_na':
$v=trim($value);
return $v===''||strcasecmp($v,'N/A')===0;
case 'gt_minutes':
return floatval($value)>floatval($cmp);
case 'lt_minutes':
return floatval($value)<floatval($cmp);
case 'range_minutes':
$parts=explode('-',$cmp);
if(count($parts)!=2)return false;
$min=floatval($parts[0]);
$max=floatval($parts[1]);
$v=floatval($value);
return($v>=$min&&$v<=$max);
default:
return false;
}}
function parse_condition_pattern($pattern){
$p=trim((string)$pattern);
if($p==='*')return['op'=>'wildcard','value'=>'*'];
if(strcasecmp($p,'n/a')===0||strcasecmp($p,'na')===0)return['op'=>'empty_or_na','value'=>''];
if(preg_match('/^\+(\d+(?:\.\d+)?)$/',$p,$m))return['op'=>'gt_minutes','value'=>$m[1]];
if(preg_match('/^-(\d+(?:\.\d+)?)$/',$p,$m))return['op'=>'lt_minutes','value'=>$m[1]];
if(preg_match('/^(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)$/',$p,$m))return['op'=>'range_minutes','value'=>$m[1].'-'.$m[2]];
return['op'=>'wildcard','value'=>$p];
}
function eval_condition($cond,$header,$row){
$col=isset($cond['column'])?(string)$cond['column']:'';
$pattern=isset($cond['pattern'])?(string)$cond['pattern']:'';
if($col===''||$pattern==='')return true;
$idx=col_index($header,$col);
$val=($idx!==null&&isset($row[$idx]))?$row[$idx]:'';
$parsed=parse_condition_pattern($pattern);
$base=eval_text_op($val,$parsed['op'],$parsed['value']);
if(!empty($cond['negate']))$base=!$base;
return $base;
}
function rule_matches($rule,$header,$row){
$conds=isset($rule['conditions'])&&is_array($rule['conditions'])?$rule['conditions']:[];
if(count($conds)===0)return false;
foreach($conds as $c){
if(!eval_condition($c,$header,$row))return false;
}
return true;
}
$rulesData=load_rules($rulesFile);
$showColumns=$rulesData['show_columns']??[];
$rules=$rulesData['rules']??[];
$csvRows=load_csv($csvFile);
$csvError=null;
if($csvRows===null)$csvError='Keine CSV gefunden oder nicht lesbar: '.$csvFile;
$header=[];
$dataRows=[];
if(is_array($csvRows)&&count($csvRows)>0){
$header=array_map('trim',$csvRows[0]);
$dataRows=array_slice($csvRows,1);
}
if(!is_array($showColumns)||count($showColumns)===0)$showColumns=$header;
$filtered=[];
if(is_array($dataRows)&&count($dataRows)>0){
if(is_array($rules)&&count($rules)>0){
foreach($dataRows as $row){
$matched=false;
foreach($rules as $r){
if(rule_matches($r,$header,$row)){$matched=true;break;}
}
if($matched)$filtered[]=$row;
}
}else{
    $filtered=[];
}
}
function cell_by_colname($header,$row,$colName){
$idx=col_index($header,$colName);
return($idx!==null&&isset($row[$idx]))?$row[$idx]:'';
}
function cell_is_trigger($header,$row,$colName,$rules){
foreach($rules as $rule){
$conds=isset($rule['conditions'])&&is_array($rule['conditions'])?$rule['conditions']:[];
foreach($conds as $c){
if(!isset($c['column']))continue;
if(strcasecmp(trim($c['column']),trim($colName))!==0)continue;
if(eval_condition($c,$header,$row))return true;
}}
return false;
}
?>
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="color-scheme" content="only light">
<link rel="icon" type="image/svg+xml" href="icon.svg">
<title>CSV Report</title>
<style>
body{font-family:Arial,Helvetica,sans-serif;margin:18px;background:#ffffff;color:#000000}
table{border-collapse:collapse;width:100%;background:#ffffff}
th,td{border:1px solid #ddd;padding:6px 8px;text-align:left;background:#ffffff;color:#000000}
th{background:#f6f6f6;color:#000000}
.error{color:#900;font-weight:bold;margin-bottom:8px}
.fk-menu-btn{position:fixed;top:10px;left:10px;z-index:999999;background:#111;color:#fff;border:none;padding:10px 14px;font-size:20px;cursor:pointer;border-radius:4px}
.fk-menu-overlay{position:fixed;inset:0;display:none;z-index:999998}
.fk-menu-overlay.is-visible{display:block}
.fk-menu-backdrop{position:absolute;inset:0;background:rgba(0,0,0,0.55)}
.fk-menu-panel{position:absolute;top:0;left:0;width:260px;height:100%;background:#fff;padding:20px;box-sizing:border-box;transform:translateX(-100%);transition:transform .25s ease-out}
.fk-menu-overlay.is-visible .fk-menu-panel{transform:translateX(0)}
.fk-menu-close{background:none;border:none;font-size:28px;cursor:pointer;margin-left:auto;display:block;color:#000}
.fk-menu-nav{margin-top:20px;display:flex;flex-direction:column;gap:12px}
.fk-menu-link{text-decoration:none;font-size:18px;color:#222}
.fk-menu-link:hover{color:#0070ff}
</style>
</head>
<body>
<button class="fk-menu-btn" data-fk-menu-btn>☰</button>
<div class="fk-menu-overlay" data-fk-menu-overlay aria-hidden="true">
<div class="fk-menu-backdrop" data-fk-menu-close></div>
<div class="fk-menu-panel">
<button class="fk-menu-close" data-fk-menu-close>×</button>
<nav class="fk-menu-nav">
<a href="rules.php" class="fk-menu-link">rules.php</a>
<a href="rules.json" class="fk-menu-link">rules.json</a>
<a href="<?php echo h($CSV_FILE);?>" class="fk-menu-link"><?php echo h($CSV_FILE);?></a>
<a href="update_log.txt" class="fk-menu-link">update_log.txt</a>
</nav>
</div>
</div>
<script>
(function(){"use strict";var btn=document.querySelector("[data-fk-menu-btn]");var overlay=document.querySelector("[data-fk-menu-overlay]");var closers=document.querySelectorAll("[data-fk-menu-close]");var isOpen=false;if(!btn||!overlay)return;function openMenu(){if(isOpen)return;isOpen=true;overlay.classList.add("is-visible");overlay.setAttribute("aria-hidden","false");document.documentElement.style.overflow="hidden"}function closeMenu(){if(!isOpen)return;isOpen=false;overlay.classList.remove("is-visible");overlay.setAttribute("aria-hidden","true");document.documentElement.style.overflow=""}btn.addEventListener("click",function(e){e.stopPropagation();isOpen?closeMenu():openMenu()});closers.forEach(function(el){el.addEventListener("click",closeMenu)});overlay.addEventListener("click",function(e){var panel=overlay.querySelector(".fk-menu-panel");if(panel&&!panel.contains(e.target))closeMenu()});document.addEventListener("keydown",function(e){if(e.key==="Escape")closeMenu()})})();
</script>
<h2>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;CSV-Liste</h2>
<?php if($csvError):?><div class="error"><?php echo h($csvError);?></div><?php endif;?>
<h3>Ergebnisse (<?php echo count($filtered);?>)</h3>
<table>
<thead>
<tr>
<?php foreach($showColumns as $col):?>
<th><?php echo h($col);?></th>
<?php endforeach;?>
</tr>
</thead>
<tbody>
<?php if(count($filtered)===0):?>
<tr><td colspan="<?php echo count($showColumns);?>">Keine Zeilen entsprechen den Regeln.</td></tr>
<?php else:foreach($filtered as $row):?>
<tr>
<?php foreach($showColumns as $col):$isTrigger=cell_is_trigger($header,$row,$col,$rules);?>
<td<?php if($isTrigger)echo' style="background:#ffe5e5"';?>><?php echo h(cell_by_colname($header,$row,$col));?></td>
<?php endforeach;?>
</tr>
<?php endforeach;endif;?>
</tbody>
</table>
</body>
</html>
