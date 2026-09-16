/* RepairMitra Customer Auth Fix
   Replaces the fragile customer auth handlers with robust Supabase Auth handling.
*/
(function () {
  const waitForSupabase = (fn) => {
    if (window.sb && window.supabase) return fn();
    setTimeout(() => waitForSupabase(fn), 50);
  };

  waitForSupabase(() => {
    const auth = window.sb;
    const el = (id) => document.getElementById(id);

    function show(id, text, ok) {
      const box = el(id);
      if (!box) return;
      box.textContent = text;
      box.className = 'msg ' + (ok ? 'ok' : 'err');
      box.style.display = 'block';
    }

    function friendlyError(error) {
      const m = String(error?.message || error || 'Unknown error');
      if (/invalid login credentials/i.test(m)) return 'Email या password गलत है। सही details डालकर फिर कोशिश करें।';
      if (/email not confirmed/i.test(m)) return 'यह email अभी verify नहीं हुआ है। Inbox/Spam में verification email खोलकर Confirm करें, फिर Sign In करें।';
      if (/user already registered/i.test(m)) return 'इस email से account पहले से बना हुआ है। सीधे Sign In करें।';
      if (/password/i.test(m) && /6|short|weak/i.test(m)) return 'Password कम से कम 6 characters का रखें।';
      return m;
    }

    async function ensureCustomerProfile(u) {
      if (!u?.id) return;
      const meta = u.user_metadata || {};
      const payload = {
        id: u.id,
        name: String(meta.full_name || meta.name || (u.email || '').split('@')[0] || 'Customer'),
        full_name: String(meta.full_name || meta.name || (u.email || '').split('@')[0] || 'Customer'),
        phone: String(meta.phone || ''),
        role: 'customer',
        is_active: true
      };
      const r = await auth.from('profiles').upsert(payload, { onConflict: 'id' });
      if (r.error) console.warn('Customer profile sync:', r.error.message);
    }

    window.login = async function () {
      const email = String(el('email')?.value || '').trim().toLowerCase();
      const password = String(el('password')?.value || '');
      if (!email || !password) return show('loginMsg', 'Email और password दोनों भरें।', false);

      const btn = document.querySelector('#loginBox button.btn');
      if (btn) { btn.disabled = true; btn.textContent = 'Signing in...'; }
      show('loginMsg', 'Checking account...', true);

      try {
        const r = await auth.auth.signInWithPassword({ email, password });
        if (r.error) throw r.error;
        if (!r.data?.user || !r.data?.session) throw new Error('Login session नहीं बन पाई। कृपया फिर कोशिश करें।');
        await ensureCustomerProfile(r.data.user);
        show('loginMsg', 'Login successful. Opening your account...', true);
        if (typeof window.openApp === 'function') window.openApp(r.data.user);
      } catch (e) {
        show('loginMsg', friendlyError(e), false);
      } finally {
        if (btn) { btn.disabled = false; btn.textContent = 'Sign In'; }
      }
    };

    window.signup = async function () {
      const name = String(el('name')?.value || '').trim();
      const phone = String(el('phone')?.value || '').trim();
      const email = String(el('signupEmail')?.value || '').trim().toLowerCase();
      const password = String(el('signupPassword')?.value || '');

      if (!name) return show('signupMsg', 'Full Name भरें।', false);
      if (!phone) return show('signupMsg', 'Mobile Number भरें।', false);
      if (!/^\S+@\S+\.\S+$/.test(email)) return show('signupMsg', 'Valid email address डालें।', false);
      if (password.length < 6) return show('signupMsg', 'Password कम से कम 6 characters का होना चाहिए।', false);

      const btn = document.querySelector('#signupBox button.btn.success');
      if (btn) { btn.disabled = true; btn.textContent = 'Creating...'; }
      show('signupMsg', 'Account बनाया जा रहा है...', true);

      try {
        const r = await auth.auth.signUp({
          email,
          password,
          options: {
            data: { full_name: name, phone, role: 'customer' },
            emailRedirectTo: window.location.origin + '/customer.html'
          }
        });
        if (r.error) throw r.error;

        if (r.data?.session && r.data?.user) {
          await ensureCustomerProfile(r.data.user);
          show('signupMsg', 'Account successfully created. Login हो गया है।', true);
          if (typeof window.openApp === 'function') window.openApp(r.data.user);
        } else {
          show('signupMsg', 'Account बन गया है। अब email के Inbox/Spam में verification link खोलें। Verification के बाद इसी email और password से Sign In करें।', true);
        }
      } catch (e) {
        show('signupMsg', friendlyError(e), false);
      } finally {
        if (btn) { btn.disabled = false; btn.textContent = 'Create Account'; }
      }
    };

    window.init = async function () {
      try {
        const r = await auth.auth.getSession();
        if (r.error) throw r.error;
        if (r.data?.session?.user) {
          await ensureCustomerProfile(r.data.session.user);
          if (typeof window.openApp === 'function') window.openApp(r.data.session.user);
        }
      } catch (e) {
        console.warn('Customer auth init:', e.message || e);
      }
    };

    auth.auth.onAuthStateChange(async (event, session) => {
      if ((event === 'SIGNED_IN' || event === 'INITIAL_SESSION') && session?.user) {
        await ensureCustomerProfile(session.user);
      }
    });
  });
})();
