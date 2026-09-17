(()=>{'use strict';
const SUPABASE_URL='https://rqnmshqrwntxilwnhqwa.supabase.co';
const SUPABASE_KEY='sb_publishable_irYxUMcbJIIKVkCtyxjp-w_piB5mu7vK';
const esc=v=>String(v??'').replace(/[&<>\"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',"'":'&#39;'}[c]));

/* Homepage UI bug fixes: keep the supplied reference layout, correct spacing/order,
   prevent mobile overflow, and keep the existing admin product feed working. */
const style=document.createElement('style');
style.id='mks-ui-fixes';
style.textContent=`
*{box-sizing:border-box}html{overflow-x:hidden}body{overflow-x:hidden}
.wrap{width:100%;max-width:1320px;margin:0 auto}
.top-strip{min-width:0;overflow:hidden}.top-strip>div{min-width:0}.top-strip>div:last-child{display:flex;align-items:center;justify-content:flex-end;gap:8px;white-space:nowrap}.top-strip span{white-space:nowrap}
.main-header{min-width:0}.brand{flex-shrink:0}.brand-name{white-space:nowrap}.search{min-width:0}.search input{min-width:0}.head-actions{flex-shrink:0}.head-action{flex-shrink:0}
.nav{overflow-x:auto;overflow-y:visible;scrollbar-width:none}.nav::-webkit-scrollbar{display:none}.nav .book{flex-shrink:0}
.hero-main,.side-banner{isolation:isolate}.hero-main .banner,.side-banner .banner{min-width:100%;min-height:100%}
.section-head{gap:12px}.section-head>div{min-width:0}.section-head a{white-space:nowrap}
/* Match reference order: Latest Products -> Repair CTA -> service features -> footer. */
.vip-strip{display:none!important}
.home-products{margin-top:27px!important;position:relative;z-index:1}
.home-products+.section{margin-top:20px!important}
.home-products .hp-head{display:flex;align-items:end;justify-content:space-between;gap:12px;margin-bottom:12px}.home-products .hp-head>div{min-width:0}.home-products .hp-head h2{margin:0;font-size:20px}.home-products .hp-head p{margin:4px 0 0;color:#748093;font-size:11px}.home-products .hp-all{background:#14233a;color:#fff;text-decoration:none;padding:9px 13px;border-radius:999px;font-weight:800;font-size:10px;white-space:nowrap}
.home-products .hp-tabs{display:flex;gap:7px;overflow-x:auto;scrollbar-width:none;padding:1px 1px 10px}.home-products .hp-tabs::-webkit-scrollbar{display:none}.home-products .hp-tab{border:1px solid #dfe5ed;background:#fff;color:#465467;border-radius:999px;padding:8px 13px;font-size:10px;font-weight:800;white-space:nowrap;cursor:pointer}.home-products .hp-tab.active{background:#0755d9;color:#fff;border-color:#0755d9}
.home-products .hp-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:12px}.home-products .hp-card{min-width:0;background:#fff;border:1px solid #e5eaf0;border-radius:10px;overflow:hidden;box-shadow:0 5px 18px #203b5d0b;display:flex;flex-direction:column;transition:.2s}.home-products .hp-card:hover{transform:translateY(-3px);box-shadow:0 12px 28px #203b5d18}.home-products .hp-img{height:180px;background:#fff;display:flex;align-items:center;justify-content:center;overflow:hidden;border-bottom:1px solid #f0f2f5}.home-products .hp-img img{width:100%;height:100%;object-fit:contain}.home-products .hp-info{padding:11px;min-width:0}.home-products .hp-badge{display:inline-block;background:#eef4ff;color:#0755d9;border-radius:4px;padding:4px 6px;font-size:8px;font-weight:900}.home-products .hp-name{font-size:12px;margin:7px 0 4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.home-products .hp-meta{font-size:9px;color:#7b8797;min-height:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.home-products .hp-price{font-size:15px;font-weight:900;margin:7px 0 3px}.home-products .hp-stock{font-size:9px;font-weight:800;color:#16834d}.home-products .hp-out{color:#b91c1c}.home-products .hp-buy{display:block;text-align:center;text-decoration:none;background:#0755d9;color:#fff;padding:8px;border-radius:6px;margin-top:8px;font-size:9px;font-weight:900}.home-products .hp-empty,.home-products .hp-loading{grid-column:1/-1;background:#fff;border:1px dashed #cbd5e1;border-radius:10px;padding:25px;text-align:center;color:#64748b;font-size:12px}
/* Repair CTA and service features should never overlap or squeeze horizontally. */
.cta{min-width:0}.cta>div{min-width:0}.cta>div:last-child{display:flex;flex-wrap:wrap;gap:8px}.features{min-width:0}.feature{min-width:0}.footer{min-width:0}.footer>div{min-width:0}.footer div{overflow-wrap:anywhere}
@media(max-width:1050px){.main-header{gap:12px}.brand{min-width:210px}.head-actions{gap:9px}.cats{grid-template-columns:repeat(4,1fr)}.home-products .hp-grid{grid-template-columns:repeat(4,minmax(0,1fr))}.footer{grid-template-columns:repeat(2,1fr)}}
@media(max-width:760px){
 .wrap{padding-left:9px!important;padding-right:9px!important}.top-strip{height:30px;font-size:9px;justify-content:center}.top-strip>div:first-child{display:none}.top-strip>div:last-child{justify-content:center;width:100%;gap:7px}.top-strip span{margin-right:0!important}.top-strip span:first-child{display:none}
 .main-header{padding:10px 4px!important;gap:8px!important;flex-wrap:wrap}.brand{min-width:0;flex:1}.brand-mark{width:42px;height:42px;font-size:22px}.brand-name{font-size:19px}.brand-name small{font-size:7px}.search{order:3;flex-basis:100%;height:40px}.search select{width:100px}.head-actions{gap:6px}.head-action{font-size:9px}.head-action i{font-size:17px}.dotsMenu{width:34px;height:34px}
 .nav{margin-left:-9px;margin-right:-9px;border-radius:0;padding:6px 9px}.nav a{font-size:10px;padding:9px 11px}.nav .book{margin-left:0}
 .hero-layout{grid-template-columns:1fr;margin-top:10px}.hero-main{min-height:0;aspect-ratio:1200/520}.side-stack{display:none}
 .section{margin-top:20px}.section-head{align-items:flex-end}.section-head h2{font-size:17px}.section-head p{font-size:10px}.section-head a{font-size:10px}
 .cats{grid-template-columns:repeat(4,1fr);gap:7px}.cat{padding:10px 5px;min-height:105px}.cat .icon{width:38px;height:38px;font-size:18px}
 .home-products{margin-top:22px!important}.home-products .hp-head{align-items:flex-start}.home-products .hp-head h2{font-size:17px}.home-products .hp-head p{font-size:10px}.home-products .hp-all{font-size:9px;padding:8px 10px}.home-products .hp-grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}.home-products .hp-img{height:155px}.home-products .hp-name{font-size:11px}.home-products .hp-price{font-size:14px}.home-products .hp-buy{font-size:9px}
 .cta{padding:17px!important;align-items:flex-start!important;flex-direction:column!important}.cta>div:last-child{width:100%}.cta .btn{flex:1;text-align:center;min-width:135px}.features{grid-template-columns:repeat(2,1fr)}.feature{border-bottom:1px solid #edf0f4}.footer{grid-template-columns:1fr 1fr;gap:15px}.copyright{font-size:8px}
}
@media(max-width:430px){.cats{grid-template-columns:repeat(2,1fr)}.home-products .hp-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.home-products .hp-img{height:145px}.home-products .hp-info{padding:9px}.home-products .hp-name{font-size:11px}.home-products .hp-price{font-size:14px}.footer{grid-template-columns:1fr}.copyright{flex-direction:column;gap:4px}.head-action:nth-child(1){display:none}.brand-name{font-size:17px}.search select{width:90px}.cta .btn{width:100%;min-width:0}}
`;
document.head.appendChild(style);

const sec=document.createElement('section');
sec.className='section home-products';
sec.innerHTML=`<div class="hp-head"><div><h2>🔥 Latest Products</h2><p>New products added by Admin appear here automatically.</p></div><a class="hp-all" href="shop.html">View All →</a></div><div class="hp-tabs"><button class="hp-tab active" data-c="">All</button><button class="hp-tab" data-c="New Mobile">New Mobile</button><button class="hp-tab" data-c="Old Mobile">Old Mobile</button><button class="hp-tab" data-c="Keypad Mobile">Keypad Mobile</button><button class="hp-tab" data-c="Footwear">Footwear</button><button class="hp-tab" data-c="Accessories">Accessories</button></div><div id="hpGrid" class="hp-grid"><div class="hp-loading">Loading products…</div></div>`;
const cats=document.querySelector('.cats');
if(cats&&cats.parentElement)cats.parentElement.after(sec);else document.querySelector('.wrap')?.append(sec);

/* Move the repair CTA before the feature row to match the reference UI. */
const cta=document.querySelector('.cta');
const features=document.querySelector('.features')?.closest('.section');
if(cta&&features&&cta.parentElement===features.parentElement){features.parentElement.insertBefore(cta,features)}

let all=[],cat='';
const db=window.supabase?.createClient(SUPABASE_URL,SUPABASE_KEY);
async function load(){
 if(!db)return;
 try{const r=await db.from('products').select('*').eq('is_active',true).order('created_at',{ascending:false});
  if(r.error){document.getElementById('hpGrid').innerHTML='<div class="hp-empty">Products could not be loaded right now.</div>';return}
  all=r.data||[];render();
 }catch(e){document.getElementById('hpGrid').innerHTML='<div class="hp-empty">Products could not be loaded right now.</div>'}
}
function render(){
 const a=cat?all.filter(p=>p.category===cat):all,g=document.getElementById('hpGrid');
 if(!a.length){g.innerHTML='<div class="hp-empty">No products added yet in this category.</div>';return}
 g.innerHTML=a.slice(0,12).map(p=>{
  const stock=Number(p.stock_quantity??p.stock??0),price=Number(p.price??p.selling_price??0),img=p.image_url||'';
  return `<article class="hp-card"><div class="hp-img">${img?`<img src="${esc(img)}" alt="${esc(p.name)}" loading="lazy" onerror="this.style.display='none'">`:'<div style="font-size:55px">📦</div>'}</div><div class="hp-info"><span class="hp-badge">${esc(p.category||'Product')}</span><h3 class="hp-name">${esc(p.name||'Product')}</h3><div class="hp-meta">${esc([p.brand,p.model].filter(Boolean).join(' • '))}</div><div class="hp-price">₹${price.toLocaleString('en-IN')}</div><div class="hp-stock ${stock<1?'hp-out':''}">${stock>0?stock+' in stock':'Out of stock'}</div>${stock>0?`<a class="hp-buy" href="shop.html?category=${encodeURIComponent(p.category||'')}">View / Buy</a>`:'<span class="hp-buy" style="background:#94a3b8">Out of Stock</span>'}</div></article>`
 }).join('');
}
sec.querySelectorAll('.hp-tab').forEach(b=>b.addEventListener('click',()=>{sec.querySelectorAll('.hp-tab').forEach(x=>x.classList.remove('active'));b.classList.add('active');cat=b.dataset.c||'';render()}));
load();
window.addEventListener('focus',load);
})();