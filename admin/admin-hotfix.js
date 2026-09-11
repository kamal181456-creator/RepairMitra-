(function(){'use strict';
const URL='https://rqnmshqrwntxilwnhqwa.supabase.co';
const KEY='sb_publishable_irYxUMcbJIIKVkCtyxjp-w_piB5mu7v';
function esc(v){return String(v??'').replace(/[&<>\"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',"'":'&#39;'}[c]))}
function boot(){
 const f=document.getElementById('adminFrame'); if(!f)return;
 try{
  const w=f.contentWindow,d=f.contentDocument; if(!w||!d||!d.getElementById('app')||!w.supabase)return;
  const db=w.sb||w.supabase.createClient(URL,KEY); w.sb=db;
  w.saveProduct=async function(){
   const $=id=>d.getElementById(id); const name=$('pn')?.value.trim(),price=Number($('pprice')?.value);
   if(!name||!Number.isFinite(price)||price<0)return w.show('pmsg','Enter a valid product name and selling price.');
   const stock=Math.max(0,Number($('pstock')?.value)||0);
   const data={name,category:$('pc')?.value||'New Mobile',brand:$('pb')?.value.trim()||null,model:$('pmodel')?.value.trim()||null,sku:$('psku')?.value.trim()||null,price,purchase_price:Math.max(0,Number($('ppurchase')?.value)||0),stock_quantity:stock,stock:stock,image_url:$('pimage')?.value.trim()||null,description:$('pdesc')?.value.trim()||null,is_active:true,updated_at:new Date().toISOString()};
   const editing=w.editingId; const r=editing?await db.from('products').update(data).eq('id',editing):await db.from('products').insert(data);
   if(r.error)return w.show('pmsg',r.error.message||'Could not save product.');
   w.show('pmsg',editing?'Product updated successfully.':'Product saved successfully.',true); await w.loadProducts(); w.loadStock(); w.loadDashboard(); setTimeout(w.closeProduct,500);
  };
  w.loadRepairs=async function(){
   const box=d.getElementById('repairRows'); if(!box)return; const r=await db.from('complaints').select('id,brand,model,phone,issue,problem,customer_id,user_id,status,marketplace_status,repair_charge,quotation_note,quotation_status,vendor_id,created_at').order('created_at',{ascending:false});
   if(r.error){box.innerHTML='<tr><td colspan="7">'+esc(r.error.message)+'</td></tr>';return}
   const statuses=['new','accepted','in_progress','ready','completed','cancelled'];
   box.innerHTML=(r.data||[]).map(c=>{const st=c.status||({complaint_created:'new',vendors_notified:'accepted',quotes_received:'accepted',customer_viewed_quotes:'accepted',vendor_selected:'in_progress',repair_in_progress:'in_progress',repair_ready:'ready'}[c.marketplace_status]||'new');return '<tr><td><b>'+esc((c.brand||'')+' '+(c.model||'Mobile'))+'</b><br><small>'+esc(c.phone||'')+'</small></td><td>'+esc(c.issue||c.problem||'—')+'</td><td><small>'+esc(c.customer_id||c.user_id||'—')+'</small></td><td><select id="rs_'+c.id+'">'+statuses.map(s=>'<option '+(s===st?'selected':'')+'>'+s+'</option>').join('')+'</select></td><td><input id="rq_'+c.id+'" type="number" min="0" value="'+Number(c.repair_charge||0)+'"></td><td><input id="rn_'+c.id+'" value="'+esc(c.quotation_note||'')+'" placeholder="Admin note"></td><td><button class="btn" onclick="updateRepair(\''+c.id+'\')">Save</button></td></tr>'}).join('')||'<tr><td colspan="7">No repair requests.</td></tr>';
  };
  w.updateRepair=async function(id){
   const st=d.getElementById('rs_'+id)?.value||'new', map={new:'vendors_notified',accepted:'vendors_notified',in_progress:'repair_in_progress',ready:'repair_ready',completed:'completed',cancelled:'cancelled'};
   const data={status:st,marketplace_status:map[st]||st,repair_charge:Number(d.getElementById('rq_'+id)?.value)||null,quotation_note:d.getElementById('rn_'+id)?.value.trim()||null,quotation_status:st==='completed'?'approved':st==='cancelled'?'cancelled':'pending',updated_at:new Date().toISOString()};
   const r=await db.from('complaints').update(data).eq('id',id); if(r.error)return alert(r.error.message); await w.loadRepairs();
  };
  w.loadQuotes=async function(){
   const box=d.getElementById('quoteRows'); if(!box)return; const r=await db.from('repair_quotes').select('*').order('created_at',{ascending:false}); if(r.error){box.innerHTML='<tr><td colspan="5">'+esc(r.error.message)+'</td></tr>';return}
   box.innerHTML=(r.data||[]).map(q=>'<tr><td>'+esc(q.complaint_id)+'</td><td>'+esc(q.vendor_id)+'</td><td>₹'+Number(q.quote_amount||0).toLocaleString('en-IN')+'</td><td><span class="badge">'+esc(q.status||'submitted')+'</span></td><td><select id="qs_'+q.id+'">'+['submitted','accepted','rejected','cancelled'].map(s=>'<option '+(s===(q.status||'submitted')?'selected':'')+'>'+s+'</option>').join('')+'</select><button class="btn" onclick="updateQuote(\''+q.id+'\')">Save</button></td></tr>').join('')||'<tr><td colspan="5">No quotes.</td></tr>';
  };
  if(!d.getElementById('repairHotfixNotice')){const n=d.createElement('div');n.id='repairHotfixNotice';n.style.cssText='position:fixed;left:12px;bottom:12px;z-index:9999;font:700 11px Arial;color:#64748b;background:#fff;padding:5px 8px;border-radius:8px;box-shadow:0 2px 10px #0001';n.textContent='Admin fixes active';d.body.appendChild(n);}
 }catch(e){console.error('Admin hotfix:',e)}
}
const f=document.getElementById('adminFrame'); if(f){f.addEventListener('load',boot);setTimeout(boot,500);setInterval(boot,2000)}
})();
