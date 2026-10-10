// Talep formu: istemci doğrulaması + gönderim durumları.
// Kurallar lib/src/validation.dart ile aynıdır; asıl yetki sunucudadır.
'use strict';

const SERVICES = ['tesisat', 'elektrik', 'klima', 'beyazesya', 'boya', 'temizlik', 'nakliyat', 'montaj', 'cilingir', 'bahce'];
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const CONTROL_RE = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/;
const TIMEOUT_MS = 30000; // Ücretsiz sunucu uykudan uyanırken ilk istek yavaş olabilir.

const FIELDS = ['name', 'email', 'service', 'message'];
const LABELS = {
  name: 'Ad soyad',
  email: 'E-posta',
  service: 'Hizmet',
  message: 'İş açıklaması',
};

function validate(values) {
  const errors = {};
  const name = values.name.trim();
  const email = values.email.trim();
  const message = values.message.trim();

  if (!name) errors.name = 'Adınızı yazın.';
  else if (name.length < 2 || name.length > 100) errors.name = 'Ad 2–100 karakter olmalı.';
  else if (CONTROL_RE.test(name) || name.includes('\n')) errors.name = 'Ad geçersiz karakter içeriyor.';

  if (!email) errors.email = 'E-posta adresinizi yazın.';
  else if (email.length > 254 || !EMAIL_RE.test(email)) errors.email = 'Geçerli bir e-posta adresi yazın (ör. ad@firma.com).';

  if (!values.service) errors.service = 'Bir hizmet seçin.';
  else if (!SERVICES.includes(values.service)) errors.service = 'Listeden geçerli bir hizmet seçin.';

  if (!message) errors.message = 'İşinizi kısaca anlatın.';
  else if (message.length < 20) errors.message = 'Açıklama en az 20 karakter olmalı.';
  else if (message.length > 200) errors.message = 'Açıklama en fazla 200 karakter olabilir.';
  else if (CONTROL_RE.test(message)) errors.message = 'Açıklama geçersiz karakter içeriyor.';

  return errors;
}

document.addEventListener('DOMContentLoaded', () => {
  const form = document.getElementById('lead-form');
  if (!form) return;
  const status = document.getElementById('form-status');
  const button = document.getElementById('submit-btn');
  const messageInput = document.getElementById('message');
  const counter = document.getElementById('message-count');
  const buttonText = button.textContent;
  let sending = false;
  let attempted = false;

  const values = () => ({
    name: form.elements.name.value,
    email: form.elements.email.value,
    service: form.elements.service.value,
    message: form.elements.message.value,
    website: form.elements.website.value,
  });

  function setFieldError(field, message) {
    const input = form.elements[field];
    const el = document.getElementById(`${field}-error`);
    if (message) {
      input.setAttribute('aria-invalid', 'true');
      el.textContent = message;
    } else {
      input.removeAttribute('aria-invalid');
      el.textContent = '';
    }
  }

  function showErrors(errors) {
    FIELDS.forEach((f) => setFieldError(f, errors[f]));
  }

  function setStatus(kind, title, items) {
    status.hidden = false;
    status.className = `status status-${kind}`;
    status.replaceChildren();
    const p = document.createElement('p');
    p.textContent = title; // textContent: sunucu metni asla HTML olarak yorumlanmaz.
    status.append(p);
    if (items && items.length) {
      const ul = document.createElement('ul');
      items.forEach(({ field, text }) => {
        const li = document.createElement('li');
        const a = document.createElement('a');
        a.href = `#${field}`;
        a.textContent = `${LABELS[field]}: ${text}`;
        a.addEventListener('click', (e) => {
          e.preventDefault();
          form.elements[field].focus();
        });
        li.append(a);
        ul.append(li);
      });
      status.append(ul);
    }
  }

  function showErrorSummary(errors, title) {
    const items = FIELDS.filter((f) => errors[f]).map((f) => ({ field: f, text: errors[f] }));
    setStatus('error', title, items);
    status.focus();
  }

  function setSending(on) {
    sending = on;
    button.disabled = on;
    button.textContent = on ? 'Gönderiliyor…' : buttonText;
    form.setAttribute('aria-busy', String(on));
  }

  // İlk gönderim denemesinden sonra hatalar yazarken güncellenir;
  // öncesinde kullanıcı alanı terk edince (blur) kontrol edilir.
  FIELDS.forEach((f) => {
    const input = form.elements[f];
    const check = () => setFieldError(f, validate(values())[f]);
    input.addEventListener('blur', () => { if (input.value || attempted) check(); });
    input.addEventListener('input', () => { if (attempted || input.getAttribute('aria-invalid')) check(); });
  });

  messageInput.addEventListener('input', () => {
    counter.textContent = String(messageInput.value.length);
  });

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (sending) return; // Çift tıklama ile mükerrer kayıt oluşmasın.
    attempted = true;

    const data = values();
    const errors = validate(data);
    showErrors(errors);
    if (Object.keys(errors).length) {
      showErrorSummary(errors, 'Lütfen işaretli alanları düzeltin:');
      return;
    }

    setSending(true);
    setStatus('sending', 'Başvurunuz gönderiliyor…');

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

    try {
      const res = await fetch('/api/leads', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify(data),
        signal: controller.signal,
      });

      let body = null;
      try { body = await res.json(); } catch { /* JSON olmayan yanıt: aşağıda hata sayılır */ }

      // Başarı yalnızca sunucu kaydı oluşturduğunu açıkça bildirdiğinde.
      if (res.status === 201 && body && body.ok === true && body.id != null) {
        form.reset();
        counter.textContent = '0';
        attempted = false;
        showErrors({});
        setStatus('success', `Başvurunuz alındı (başvuru no: ${body.id}). Ekibimiz iki iş günü içinde e-posta ile dönüş yapacak.`);
        status.focus();
        return;
      }

      const serverErrors = (body && body.errors) || {};
      if (res.status === 400 && FIELDS.some((f) => serverErrors[f])) {
        showErrors(serverErrors);
        showErrorSummary(serverErrors, 'Sunucu bazı alanları kabul etmedi:');
        return;
      }

      // Formu silmiyoruz: kullanıcı tekrar deneyebilsin.
      setStatus('error', serverErrors.form ||
        'Başvurunuz kaydedilemedi. Lütfen biraz sonra tekrar deneyin; bilgileriniz formda duruyor.');
      status.focus();
    } catch (err) {
      const timedOut = err && err.name === 'AbortError';
      setStatus('error', timedOut
        ? 'Sunucu zamanında yanıt vermedi, başvurunuz kaydedilmemiş olabilir. Lütfen tekrar deneyin.'
        : 'Bağlantı kurulamadı, başvurunuz gönderilmedi. İnternet bağlantınızı kontrol edip tekrar deneyin.');
      status.focus();
    } finally {
      clearTimeout(timer);
      setSending(false);
    }
  });
});
