/* RepairMitra marketplace repair flow hardening/fixes */
(function(){
  const SB = window.sb;
  if (!SB) return;
  const $ = id => document.getElementById(id);
  const esc2 = v => String(v ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

  window.openQuotes = async function(id){
    if (!window.user) return;
    window.currentComplaint = String(id);
    if (typeof window.page === 'function') window.page('quotes');
    if ($('quoteHint')) $('quoteHint').textContent='Loading vendor quotations…';
    if ($('quoteList')) $('quoteList').innerHTML='<div class="item"><p class="muted">Please wait…</p></div>';
    const r = await SB.from('repair_quotes').select('*').eq('complaint_id',String(id)).order('quote_amount',{ascending:true});
    if (r.error){ if($('quoteList')) $('quoteList').innerHTML='<p class="muted">'+esc2(r.error.message)+'</p>'; return; }
    const quotes = r.data || [];
    if (!quotes.length){
      if($('quoteHint')) $('quoteHint').textContent='Your complaint has been sent to approved vendors. Quotes will appear here as vendors respond.';
      if($('quoteList')) $('quoteList').innerHTML='<div class="item"><h3>⏳ Waiting for quotations</h3><p class="muted">No vendor has submitted a quotation yet.</p></div>';
      return;
    }
    const ids=[...new Set(quotes.map(q=>q.vendor_id).filter(Boolean))];
    let shops=[];
    if(ids.length){
      const s=await SB.from('vendor_shops').select('vendor_id,shop_name,owner_name,city,area,pincode,services,is_approved,is_active').in('vendor_id',ids);
      if(!s.error) shops=s.data||[];
    }
    const shopMap=Object.fromEntries(shops.map(x=>[x.vendor_id,x]));
    if($('quoteHint')) $('quoteHint').textContent=`${quotes.length} quotation${quotes.length===1?'':'s'} received. Compare price, time and service details, then choose one vendor.`;
    if($('quoteList')) $('quoteList').innerHTML=quotes.map((q,i)=>{
      const s=shopMap[q.vendor_id]||{};
      const shop=s.shop_name||('Verified Vendor '+(i+1));
      const services=Array.isArray(s.services)?s.services.join(', '):(s.services||'Mobile repair');
      return `<div class="item" style="border:2px solid ${i===0?'#2563eb':'#e2e8f0'}">
        <div style="display:flex;justify-content:space-between;gap:12px;align-items:flex-start">
          <div><h3 style="margin:0 0 5px">👨‍🔧 ${esc2(shop)}</h3><p class="muted" style="margin:0">${esc2(s.area||s.city||'Local repair vendor')}</p></div>
          <div class="price">₹${esc2(q.quote_amount)}</div>
        </div>
        <p><b>Estimated time:</b> ${esc2(q.estimated_time||'Not specified')}</p>
        <p><b>Problem/Service:</b> ${esc2(q.service_details||'Repair as described in complaint')}</p>
        <p><b>Parts:</b> ${esc2(q.parts_details||'Not specified')}</p>
        <p><b>Vendor message:</b> ${esc2(q.vendor_note||'No additional message')}</p>
        <p class="muted"><b>Services:</b> ${esc2(services)}</p>
        <div class="actions"><button class="btn success" onclick="selectVendor('${esc2(q.id)}','${esc2(q.vendor_id)}')">✅ Choose This Vendor</button><button class="btn secondary" onclick="openChat('${esc2(q.vendor_id)}')">💬 Message Vendor</button></div>
      </div>`;
    }).join('');
  };

  window.selectVendor = async function(quoteId,vendorId){
    if(!window.user || !window.currentComplaint) return;
    if(!confirm('Choose this vendor and quotation?')) return;
    const check=await SB.from('complaints').select('id,customer_id,user_id').eq('id',String(window.currentComplaint)).maybeSingle();
    if(check.error || !check.data || (check.data.customer_id!==window.user.id && check.data.user_id!==window.user.id)) return alert('You can only select a vendor for your own complaint.');
    const q=await SB.from('repair_quotes').select('id,vendor_id,quote_amount').eq('id',String(quoteId)).eq('complaint_id',String(window.currentComplaint)).maybeSingle();
    if(q.error || !q.data || q.data.vendor_id!==vendorId) return alert('Quotation not found. Please refresh and try again.');
    const up=await SB.from('complaints').update({selected_vendor_id:vendorId,selected_quote_id:quoteId,marketplace_status:'vendor_selected',quotation_status:'selected',repair_charge:q.data.quote_amount}).eq('id',String(window.currentComplaint)).eq('customer_id',window.user.id);
    if(up.error) return alert(up.error.message);
    const order=await SB.from('repair_orders').upsert({complaint_id:String(window.currentComplaint),customer_id:window.user.id,vendor_id:vendorId,quote_id:quoteId,status:'vendor_selected',agreed_amount:q.data.quote_amount,updated_at:new Date().toISOString()},{onConflict:'complaint_id'});
    if(order.error) return alert('Vendor selected, but order could not be created: '+order.error.message);
    alert('Vendor selected successfully.');
    if(typeof window.loadRepairs==='function') await window.loadRepairs();
    if(typeof window.page==='function') window.page('repairs');
  };

  window.loadRepairs = async function(){
    if(!window.user || !window.$) return;
    const r=await SB.from('complaints').select('id,brand,model,mobile_model,problem,issue,description,address,status,marketplace_status,selected_vendor_id,created_at').order('created_at',{ascending:false});
    if(r.error){if($('list')) $('list').innerHTML='<p class="muted">'+esc2(r.error.message)+'</p>';return;}
    const rows=r.data||[];
    if(!rows.length){$('list').innerHTML='<p class="muted">No repair requests available.</p>';return;}
    const ids=rows.map(x=>String(x.id));
    const qr=ids.length?await SB.from('repair_quotes').select('*').eq('vendor_id',window.user.id).in('complaint_id',ids):{data:[]};
    const own=Object.fromEntries((qr.data||[]).map(q=>[String(q.complaint_id),q]));
    $('list').innerHTML=rows.map(c=>{
      const q=own[String(c.id)];
      const selected=c.selected_vendor_id;
      const selectedByOther=!!selected && selected!==window.user.id;
      const title=c.mobile_model || [c.brand,c.model].filter(Boolean).join(' ') || 'Mobile';
      return `<div class="item"><h3>📱 ${esc2(title)}</h3>
        <p><b>Problem:</b> ${esc2(c.problem||c.issue||'-')}</p>
        <p><b>Details:</b> ${esc2(c.description||'-')}</p>
        <p><b>Address:</b> ${esc2(c.address||'-')}</p>
        <p><b>Status:</b> ${esc2(c.marketplace_status||c.status||'New')}</p>
        ${selectedByOther?'<p class="muted">This customer has already selected another vendor.</p>':''}
        ${q?`<div style="background:#f0fdf4;border-radius:12px;padding:12px"><b>✅ Your quotation</b><br>₹${esc2(q.quote_amount)} • ${esc2(q.estimated_time||'Time not specified')}<br>${esc2(q.vendor_note||q.service_details||'')}</div>`:`<div class="quote-box" data-id="${esc2(c.id)}">
          <input id="amt_${esc2(c.id)}" type="number" min="1" placeholder="Your Quote Amount ₹">
          <input id="time_${esc2(c.id)}" placeholder="Estimated repair time (e.g. 2 hours)">
          <input id="parts_${esc2(c.id)}" placeholder="Parts / spare parts details">
          <textarea id="service_${esc2(c.id)}" placeholder="What repair/service will you do?"></textarea>
          <textarea id="note_${esc2(c.id)}" placeholder="Message to customer"></textarea>
          <button class="btn success" ${selectedByOther?'disabled':''} onclick="quote('${esc2(c.id)}')">💰 Send Quotation</button>
        </div>`}
      </div>`;
    }).join('');
  };

  window.quote = async function(id){
    if(!window.user) return;
    const amount=Number($('amt_'+id)?.value);
    if(!Number.isFinite(amount)||amount<=0) return alert('Enter a valid quotation amount.');
    const payload={complaint_id:String(id),vendor_id:window.user.id,quote_amount:amount,estimated_time:$('time_'+id)?.value.trim()||'',parts_details:$('parts_'+id)?.value.trim()||'',service_details:$('service_'+id)?.value.trim()||'',vendor_note:$('note_'+id)?.value.trim()||'',status:'submitted',updated_at:new Date().toISOString()};
    const r=await SB.from('repair_quotes').upsert(payload,{onConflict:'complaint_id,vendor_id'});
    if(r.error) return alert('Quotation error: '+r.error.message);
    alert('Quotation sent to customer successfully.');
    await window.loadRepairs();
  };
})();
