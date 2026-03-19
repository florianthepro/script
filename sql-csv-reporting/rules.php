<?php
$CSV_FILE='[emty]'; #csv.csv
$rules_file=__DIR__.'/rules.json';
$backup_dir=__DIR__.'/rules_backup';
if(!is_dir($backup_dir))@mkdir($backup_dir,0775,true);

$default=['header_line'=>'','show_columns'=>[],'rules'=>[]];
$load_error='';
$save_msg='';

if($_SERVER['REQUEST_METHOD']==='POST' && ($_POST['action'] ?? '') === 'save'){
$incoming=$_POST['json']??'';
$decoded=json_decode($incoming,true);
if($decoded===null && trim($incoming)!==''){
$save_msg='Fehler: Ungültiges JSON.';
$parsed=$default;
}else{
$ts=date('Ymd_His');
if(is_readable($rules_file))@copy($rules_file,$backup_dir.'/rules.'.$ts.'.bak');
$ok=file_put_contents($rules_file,json_encode($decoded,JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE));
$save_msg=$ok===false?'Fehler beim Speichern.':'Gespeichert.';
$parsed=$decoded;
}}

if(!isset($parsed)){
$raw=is_readable($rules_file)?file_get_contents($rules_file):json_encode($default);
$parsed=json_decode($raw,true);
if(!is_array($parsed)){
$parsed=$default;
$load_error='rules.json beschädigt – Standard geladen.';
}}

$header_line=$parsed['header_line'] ?? '';
$show_columns=$parsed['show_columns'] ?? [];
$rules=$parsed['rules'] ?? [];

$csvPath=__DIR__.'/'.$CSV_FILE;
$csvCols=[];
if(is_readable($csvPath)){
$fh=fopen($csvPath,'r');
if($fh){
$first=fgetcsv($fh);
fclose($fh);
if(is_array($first))$csvCols=array_map('trim',$first);
}}
if($header_line==='' && $csvCols)$header_line=implode(',',$csvCols);
if(!$show_columns)$show_columns=$csvCols;

$cols=$csvCols ?: array_map('trim',explode(',',$header_line));
if(!is_array($cols))$cols=[];

$parsed['header_line']=$header_line;
$parsed['show_columns']=$show_columns;
$parsed['rules']=$rules;

$data_json=json_encode($parsed,JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE);
$columns_json=json_encode($cols,JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE);

function h($s){return htmlspecialchars((string)$s,ENT_QUOTES|ENT_SUBSTITUTE,'UTF-8');}
?>
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="color-scheme" content="only light">
<title>Rules Editor</title>
<link rel="icon" href="icon.svg">
<style>
body{font-family:Arial;margin:18px;background:#fff;color:#000}
h1,h2{margin:0 0 8px 0}
section{margin-top:18px}
textarea,input[type=text],select{padding:4px;border:1px solid #ccc;border-radius:3px;font-size:14px}
textarea{width:100%;min-height:40px}
button{padding:4px 10px;border:1px solid #444;border-radius:3px;background:#eee;cursor:pointer}
button.primary{background:#0070ff;color:#fff;border-color:#0050c0}
button.small{font-size:12px;padding:2px 6px}
table{border-collapse:collapse;width:100%;margin-top:6px}
th,td{border:1px solid #ddd;padding:4px;font-size:13px}
th{background:#f6f6f6}
.error{color:#900;margin-top:6px;font-weight:bold}
.info{font-size:12px;margin-top:4px;color:#333}
.condition-row{display:flex;gap:6px;margin-top:4px}
.condition-row select{width:160px}
.condition-row input[type=text]{flex:1}
.modal-backdrop{position:fixed;inset:0;background:rgba(0,0,0,.4);display:none;align-items:center;justify-content:center;z-index:999}
.modal{background:#fff;padding:12px;border-radius:4px;min-width:320px;max-width:700px;max-height:90vh;overflow:auto}
.modal-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:6px}
.modal-title{font-size:16px;font-weight:bold}
.fk-menu-btn{position:fixed;top:10px;left:10px;background:#111;color:#fff;border:none;padding:10px;font-size:20px;border-radius:4px;cursor:pointer;z-index:1000}
.fk-menu-overlay{position:fixed;inset:0;background:rgba(0,0,0,.55);display:none;z-index:999}
.fk-menu-overlay.is-visible{display:block}
.fk-menu-panel{position:absolute;top:0;left:0;width:260px;height:100%;background:#fff;padding:20px;transform:translateX(-100%);transition:.25s}
.fk-menu-overlay.is-visible .fk-menu-panel{transform:translateX(0)}
.fk-menu-nav{display:flex;flex-direction:column;gap:12px;margin-top:20px}
.fk-menu-link{text-decoration:none;font-size:18px;color:#222}
.fk-menu-link:hover{color:#0070ff}
</style>
</head>
<body>

<button class="fk-menu-btn" data-fk-menu-btn>☰</button>
<div class="fk-menu-overlay" data-fk-menu-overlay>
<div class="fk-menu-panel">
<button data-fk-menu-close style="background:none;border:none;font-size:28px;cursor:pointer;margin-left:auto">×</button>
<nav class="fk-menu-nav">
<a class="fk-menu-link" href="index.php">index.php</a>
<a class="fk-menu-link" href="rules.php">rules.php</a>
<a class="fk-menu-link" href="rules.json">rules.json</a>
<a class="fk-menu-link" href="<?php echo h($CSV_FILE);?>"><?php echo h($CSV_FILE);?></a>
<a class="fk-menu-link" href="update_log.txt">update_log.txt</a>
</nav>
</div>
</div>

<script>
(function(){
let b=document.querySelector("[data-fk-menu-btn]");
let o=document.querySelector("[data-fk-menu-overlay]");
if(!b||!o)return;
b.onclick=()=>o.classList.add("is-visible");
o.onclick=e=>{if(!e.target.closest(".fk-menu-panel"))o.classList.remove("is-visible")};
})();
</script>

<h1>Rules Editor</h1>

<?php if($save_msg){?><div class="info"><?php echo h($save_msg);?></div><?php } ?>
<?php if($load_error){?><div class="error"><?php echo h($load_error);?></div><?php } ?>

<form method="post" id="rules-form">
<input type="hidden" name="action" value="save">
<input type="hidden" name="json" id="rules-json">

<section>
<h2>Spalten</h2>
<label>Header-Zeile</label>
<textarea id="header-line-input"><?php echo h($header_line);?></textarea>

<div style="margin-top:8px">Anzuzeigende Spalten:</div>
<div style="display:flex;flex-wrap:wrap;gap:8px;">
<?php foreach($cols as $c){ $checked=in_array($c,$show_columns,true); ?>
<label><input type="checkbox" class="show-col-cb" value="<?php echo h($c);?>"<?php if($checked)echo' checked';?>> <?php echo h($c);?></label>
<?php } ?>
</div>
</section>

<section>
<h2>Regeln</h2>
<button type="button" class="primary" onclick="openRule(-1)">Regel hinzufügen</button>

<table>
<thead><tr><th>#</th><th>Beschreibung</th><th>Aktionen</th></tr></thead>
<tbody id="rules-body"></tbody>
</table>
</section>

<div style="margin-top:14px">
<button type="submit" class="primary">Speichern</button>
<button type="button" onclick="openHelp()" style="margin-left:8px">Hilfe</button>
</div>
</form>

<div class="modal-backdrop" id="rule-modal">
<div class="modal">
<div class="modal-header">
<div class="modal-title">Regel bearbeiten</div>
<button onclick="closeRule()" class="modal-close">×</button>
</div>

<label>Beschreibung</label>
<input type="text" id="r-desc">

<label>Bedingungen (UND)</label>
<div id="r-conds"></div>
<button type="button" class="small" onclick="addCond()">+ Bedingung</button>

<div style="margin-top:10px;display:flex;justify-content:flex-end;gap:6px">
<button onclick="closeRule()">Abbrechen</button>
<button class="primary" onclick="applyRule()">Übernehmen</button>
</div>
</div>
</div>

<div class="modal-backdrop" id="help-modal">
<div class="modal">
<div class="modal-header">
<div class="modal-title">Regel-Muster Hilfe</div>
<button onclick="closeHelp()" class="modal-close">×</button>
</div>
<ul>
<li>* → Wildcard</li>
<li>n/a → leer oder N/A</li>
<li>+30 → größer als 30</li>
<li>-10 → kleiner als 10</li>
<li>5-60 → Bereich</li>
<li>*prio* → enthält "prio"</li>
</ul>
</div>
</div>

<script>
var DATA=<?php echo $data_json;?>;
var COLS=<?php echo $columns_json;?>;
if(!Array.isArray(DATA.rules))DATA.rules=[];

function sync(){
DATA.header_line=document.getElementById("header-line-input").value||"";
var v=[];document.querySelectorAll(".show-col-cb").forEach(x=>{if(x.checked)v.push(x.value);});
DATA.show_columns=v;
document.getElementById("rules-json").value=JSON.stringify(DATA);
}
document.getElementById("rules-form").onsubmit=sync;

function render(){
let tb=document.getElementById("rules-body");
tb.innerHTML="";
DATA.rules.forEach((r,i)=>{
let tr=document.createElement("tr");
tr.innerHTML="<td>"+(i+1)+"</td><td>"+h(r.description||("Regel "+(i+1)))+"</td>";
let td=document.createElement("td");
let b1=document.createElement("button");b1.textContent="Edit";b1.className="small";b1.onclick=()=>openRule(i);
let b2=document.createElement("button");b2.textContent="X";b2.className="small";b2.style.marginLeft="4px";b2.onclick=()=>{if(confirm("Löschen?")){DATA.rules.splice(i,1);render();}};
td.appendChild(b1);td.appendChild(b2);
tr.appendChild(td);tb.appendChild(tr);
});
}

function h(s){return String(s).replace(/[<>&]/g,m=>({'<':'&lt;','>':'&gt;','&':'&amp;'}[m]));}

let edit=-1;

function openRule(i){
edit=i;
let modal=document.getElementById("rule-modal");
let r=i>=0?DATA.rules[i]:{description:"",conditions:[]};
document.getElementById("r-desc").value=r.description||"";
let c=document.getElementById("r-conds");
c.innerHTML="";
(r.conditions||[]).forEach(x=>addCond(x));
if(r.conditions.length===0)addCond();
modal.style.display="flex";
}

function closeRule(){
document.getElementById("rule-modal").style.display="none";
}

function addCond(x){
let d=document.createElement("div");
d.className="condition-row";

let s=document.createElement("select");
let o=document.createElement("option");o.value="";o.textContent="Spalte";s.appendChild(o);
COLS.forEach(col=>{let op=document.createElement("option");op.value=col;op.textContent=col;s.appendChild(op);});
let t=document.createElement("input");t.type="text";t.placeholder="Muster";
let n=document.createElement("input");n.type="checkbox";
let l=document.createElement("label");l.style.fontSize="12px";l.appendChild(n);l.appendChild(document.createTextNode(" neg."));
let rm=document.createElement("button");rm.textContent="×";rm.className="small";rm.onclick=()=>d.remove();

if(x){s.value=x.column||"";t.value=x.pattern||"";n.checked=!!x.negate;}

d.appendChild(s);d.appendChild(t);d.appendChild(l);d.appendChild(rm);

document.getElementById("r-conds").appendChild(d);
}

function applyRule(){
let desc=document.getElementById("r-desc").value.trim();
let list=[];
document.querySelectorAll("#r-conds .condition-row").forEach(r=>{
let c=r.querySelector("select").value.trim();
let p=r.querySelector("input[type=text]").value.trim();
let n=r.querySelector("input[type=checkbox]").checked;
if(c!=="" && p!=="")list.push({column:c,pattern:p,negate:n});
});
let rule={description:desc,conditions:list};
if(edit>=0)DATA.rules[edit]=rule;else DATA.rules.push(rule);
closeRule();render();
}

function openHelp(){document.getElementById("help-modal").style.display="flex";}
function closeHelp(){document.getElementById("help-modal").style.display="none";}

render();
</script>
</body>
</html>
