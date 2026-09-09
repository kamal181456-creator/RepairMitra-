/* RepairMitra - isolated Product Edit controller
   Adds ONLY Edit capability. Does not replace the existing product form,
   scanner, image flow, stock controls, delete controls, or Add Product flow.
*/
(function(){
'use strict';

const SUPABASE_URL='https://rqnmshqrwntxilwnhqwa.supabase.co';
const SUPABASE_KEY='sb_publishable_irYxUMcbJIIKVkCtyxjp-w_piB5mu7v';
let client=null;
let editProductId=null;
let cache=[];

function $(id){return document.getElementById(id)}
function clean(v){return String(v==null?'':v).trim()}
function esc(v){return String(v==null?'':v).replace(/[&<>\"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',"'":'&#39;'}[c]))}
function message(text,ok){const e=$('pmsg');if(e)e.innerHTML='<div class="msg '+(ok?'ok':'err')+'">'+esc(text)+'</div>'}
function setVal(id,v){const e=$(id);if(e)e.value=v==null?'':v}

async function getClient(){
  if(client)return client;
  if(!window.supabase||typeof window.supabase.createClient!=='function')return null;
  client=window.supabase.createClient(SUPABASE_URL,SUPABASE_KEY,{auth:{persistSession:true,autoRefreshToken:true}});
  return client;
}

async function fetchProducts(){
  const c=await getClient();
  if(!c)return [];
  const r=await c.from('products').select('*').order('created_at',{ascending:false});
  if(r.error){console.warn('RepairMitra Edit:',r.error);return cache}
  cache=r.data||[];
  return cache;
}

function productFromRow(row){
  const cells=row.querySelectorAll('td');
  if(cells.length<6)return null;
  const name=clean(cells[0].innerText).split('\n')[0];
  const sku=clean(cells[2].innerText);
  let p=cache.find(x=>clean(x.sku)===sku && sku && clean(x.name)===name);
  if(!p && sku)p=cache.find(x=>clean(x.sku)===sku);
  if(!p)p=cache.find(x=>clean(x.name)===name);
  return p||null;
}

function openEdit(p){
  if(!p)return;
  editProductId=p.id;
  setVal('pn',p.name);
  setVal('pb',p.brand);
  setVal('pmodel',p.model);
  setVal('psku',p.sku);
  setVal('pprice',p.price);
  setVal('ppurchase',p.purchase_price);
  setVal('pstock',p.stock_quantity);
  setVal('pimage',p.image_url);
  setVal('pdesc',p.description);
  const cat=$('pc');if(cat){cat.value=p.category||'New Mobile';if(!cat.value&&p.category){const o=document.createElement('option');o.value=p.category;o.textContent=p.category;cat.appendChild(o);cat.value=p.category}}
  const title=$('pt');if(title)title.textContent='✏️ Edit Product';
  const modal=$('pm');if(modal)modal.classList.add('show');
  const saveBtn=$('pm')?.querySelector('button.success');
  if(saveBtn){
    saveBtn.dataset.directEdit='1';
    saveBtn.textContent='💾 Update Product';
    saveBtn.onclick=saveEdit;
  }
  const msg=$('pmsg');if(msg)msg.innerHTML='';
}

async function saveEdit(){
  if(!editProductId)return;
  const name=clean($('pn')?.value);
  const price=Number($('pprice')?.value);
  if(!name)return message('Product name is required.');
  if(!Number.isFinite(price)||price<0)return message('Enter a valid selling price.');
  const stock=Math.max(0,Number($('pstock')?.value)||0);
  const purchase=Math.max(0,Number($('ppurchase')?.value)||0);
  const data={
    name,
    category:$('pc')?.value||'New Mobile',
    brand:clean($('pb')?.value)||null,
    model:clean($('pmodel')?.value)||null,
    sku:clean($('psku')?.value)||null,
    price,
    purchase_price:purchase,
    stock_quantity:stock,
    image_url:clean($('pimage')?.value)||null,
    description:clean($('pdesc')?.value)||null,
    updated_at:new Date().toISOString()
  };
  const c=await getClient();
  if(!c)return message('Database connection is not available.');
  const r=await c.from('products').update(data).eq('id',editProductId);
  if(r.error)return message(r.error.message||'Product update failed.');
  cache=cache.map(x=>String(x.id)===String(editProductId)?Object.assign({},x,data):x);
  message('Product updated successfully.',true);
  patchRows();
  setTimeout(()=>{
    const m=$('pm');if(m)m.classList.remove('show');
    const title=$('pt');if(title)title.textContent='➕ Add Product';
    const btn=$('pm')?.querySelector('button.success');
    if(btn){btn.textContent='Save Product';btn.removeAttribute('data-direct-edit');btn.onclick=null;}
    editProductId=null;
  },650);
}

function makeEditButton(p){
  const b=document.createElement('button');
  b.type='button';
  b.className='btn repairmitra-edit-btn';
  b.textContent='✏️ Edit';
  b.style.cssText='background:#2563eb;color:#fff;margin:3px 6px 3px 0;display:inline-block!important;visibility:visible!important;opacity:1!important;';
  b.addEventListener('click',function(e){e.preventDefault();e.stopPropagation();openEdit(p)});
  return b;
}

function patchRows(){
  const body=$('productsRows');
  if(!body)return;
  [...body.querySelectorAll('tr')].forEach(row=>{
    const cells=row.querySelectorAll('td');
    if(cells.length<6)return;
    const p=productFromRow(row);
    if(!p)return;
    const action=cells[5];
    if(action.querySelector('.repairmitra-edit-btn'))return;
    action.insertBefore(makeEditButton(p),action.firstChild);
  });
}

async function refresh(){
  await fetchProducts();
  patchRows();
}

async function boot(){
  await fetchProducts();
  patchRows();
  const body=$('productsRows');
  if(body&&!body.dataset.repairmitraObserver){
    body.dataset.repairmitraObserver='1';
    new MutationObserver(()=>setTimeout(patchRows,20)).observe(body,{childList:true,subtree:true});
  }
}

window.openProductEdit=openEdit;
window.repairMitraDirectProductEdit={refresh,openEdit};

setTimeout(boot,100);
setTimeout(boot,500);
setTimeout(boot,1200);
setTimeout(boot,2500);
setInterval(()=>{if($('productsRows')){fetchProducts().then(patchRows)}},5000);
})();
