import { useEffect, useMemo, useState } from 'react';
import { supabase, supabaseConfigured } from './supabaseClient';
import { loadTaxonomy } from './taxonomy';
import { emptyForm, type OnboardingForm as FormData, type Taxonomy } from './types';

type Status = 'idle' | 'submitting' | 'success' | 'error';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function OnboardingForm() {
  const [form, setForm] = useState<FormData>(emptyForm);
  const [taxonomy, setTaxonomy] = useState<Taxonomy | null>(null);
  const [status, setStatus] = useState<Status>('idle');
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [serverError, setServerError] = useState<string>('');

  useEffect(() => {
    void loadTaxonomy().then(setTaxonomy);
  }, []);

  // Professions available for the chosen category.
  const professionOptions = useMemo(() => {
    if (!taxonomy) return [];
    if (!form.primary_category_slug) return taxonomy.professions;
    const scoped = taxonomy.professions.filter(
      (p) => !p.categorySlug || p.categorySlug === form.primary_category_slug,
    );
    return scoped.length ? scoped : taxonomy.professions;
  }, [taxonomy, form.primary_category_slug]);

  function set<K extends keyof FormData>(key: K, value: FormData[K]) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  function toggleMulti(key: 'languages' | 'services', value: string) {
    setForm((f) => {
      const has = f[key].includes(value);
      return { ...f, [key]: has ? f[key].filter((v) => v !== value) : [...f[key], value] };
    });
  }

  function validate(): boolean {
    const e: Record<string, string> = {};
    if (!form.full_name.trim()) e.full_name = 'Your name is required.';
    if (!form.email.trim()) e.email = 'Email is required.';
    else if (!EMAIL_RE.test(form.email)) e.email = 'Enter a valid email address.';
    if (!form.headline.trim()) e.headline = 'A short headline is required.';
    if (!form.primary_category_slug) e.primary_category_slug = 'Choose a category.';
    if (!form.consent) e.consent = 'Please accept to continue.';
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  async function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    setServerError('');
    if (!validate()) return;

    if (!supabase) {
      setServerError(
        'The form is not connected to a database yet. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY.',
      );
      setStatus('error');
      return;
    }

    setStatus('submitting');
    const num = (s: string) => (s.trim() === '' ? null : Number(s));
    const str = (s: string) => (s.trim() === '' ? null : s.trim());

    const { error } = await supabase.from('onboarding_submissions').insert({
      full_name: form.full_name.trim(),
      email: form.email.trim(),
      phone: str(form.phone),
      display_name: str(form.display_name) ?? form.full_name.trim(),
      studio_name: str(form.studio_name),
      entity_type: form.entity_type,
      primary_category_slug: str(form.primary_category_slug),
      primary_profession_slug: str(form.primary_profession_slug),
      years_experience: num(form.years_experience),
      headline: form.headline.trim(),
      bio: str(form.bio),
      city: str(form.city),
      country_code: str(form.country_code),
      travel_willing: form.travel_willing,
      services: form.services,
      languages: form.languages,
      website_url: str(form.website_url),
      instagram_url: str(form.instagram_url),
      rate_min: num(form.rate_min),
      rate_max: num(form.rate_max),
      rate_currency: form.rate_currency,
      rate_unit: form.rate_unit,
      consent: form.consent,
      raw: form,
    });

    if (error) {
      setServerError(error.message);
      setStatus('error');
      return;
    }
    setStatus('success');
  }

  if (status === 'success') {
    return (
      <div className="card success" role="status">
        <h2>You're on the list 🎉</h2>
        <p>
          Thanks, {form.full_name.split(' ')[0]}. Your details are in — our team reviews new
          professionals before they go live in the directory. We'll be in touch at{' '}
          <strong>{form.email}</strong>.
        </p>
        <button
          className="btn-secondary"
          onClick={() => {
            setForm(emptyForm);
            setErrors({});
            setStatus('idle');
          }}
        >
          Submit another professional
        </button>
      </div>
    );
  }

  return (
    <form className="card" onSubmit={handleSubmit} noValidate>
      {!supabaseConfigured && (
        <div className="banner warn">
          Demo mode: database not configured. Submissions won't be saved until
          <code> VITE_SUPABASE_URL</code> and <code>VITE_SUPABASE_ANON_KEY</code> are set.
        </div>
      )}

      <section>
        <h3>About you</h3>
        <div className="grid">
          <Field label="Full name" required error={errors.full_name}>
            <input value={form.full_name} onChange={(e) => set('full_name', e.target.value)} autoComplete="name" />
          </Field>
          <Field label="Email" required error={errors.email}>
            <input type="email" value={form.email} onChange={(e) => set('email', e.target.value)} autoComplete="email" />
          </Field>
          <Field label="Phone">
            <input value={form.phone} onChange={(e) => set('phone', e.target.value)} autoComplete="tel" />
          </Field>
          <Field label="I am a / a">
            <select value={form.entity_type} onChange={(e) => set('entity_type', e.target.value)}>
              <option value="individual">Individual</option>
              <option value="studio">Studio</option>
              <option value="agency">Agency</option>
              <option value="collective">Collective</option>
            </select>
          </Field>
          <Field label="Studio / brand name">
            <input value={form.studio_name} onChange={(e) => set('studio_name', e.target.value)} />
          </Field>
          <Field label="Display name (how you'll appear)">
            <input value={form.display_name} onChange={(e) => set('display_name', e.target.value)} placeholder="Defaults to your full name" />
          </Field>
        </div>
      </section>

      <section>
        <h3>Your work</h3>
        <div className="grid">
          <Field label="Category" required error={errors.primary_category_slug}>
            <select
              value={form.primary_category_slug}
              onChange={(e) => {
                set('primary_category_slug', e.target.value);
                set('primary_profession_slug', '');
              }}
            >
              <option value="">Select a category…</option>
              {taxonomy?.categories.map((c) => (
                <option key={c.value} value={c.value}>{c.label}</option>
              ))}
            </select>
          </Field>
          <Field label="Profession">
            <select value={form.primary_profession_slug} onChange={(e) => set('primary_profession_slug', e.target.value)}>
              <option value="">Select a profession…</option>
              {professionOptions.map((p) => (
                <option key={p.value} value={p.value}>{p.label}</option>
              ))}
            </select>
          </Field>
          <Field label="Years of experience">
            <input type="number" min={0} max={80} value={form.years_experience} onChange={(e) => set('years_experience', e.target.value)} />
          </Field>
        </div>
        <Field label="Headline" required error={errors.headline}>
          <input
            value={form.headline}
            onChange={(e) => set('headline', e.target.value)}
            placeholder="e.g. Architectural & product photographer in Mumbai"
            maxLength={160}
          />
        </Field>
        <Field label="Short bio">
          <textarea rows={4} value={form.bio} onChange={(e) => set('bio', e.target.value)} placeholder="A couple of sentences about your work." />
        </Field>
        {taxonomy && taxonomy.services.length > 0 && (
          <Field label="Services offered">
            <ChipGroup options={taxonomy.services} selected={form.services} onToggle={(v) => toggleMulti('services', v)} />
          </Field>
        )}
      </section>

      <section>
        <h3>Location & languages</h3>
        <div className="grid">
          <Field label="City">
            <input value={form.city} onChange={(e) => set('city', e.target.value)} />
          </Field>
          <Field label="Country code">
            <input value={form.country_code} onChange={(e) => set('country_code', e.target.value.toUpperCase())} placeholder="IN" maxLength={2} />
          </Field>
        </div>
        <label className="checkbox">
          <input type="checkbox" checked={form.travel_willing} onChange={(e) => set('travel_willing', e.target.checked)} />
          <span>I'm open to travelling for work</span>
        </label>
        {taxonomy && (
          <Field label="Languages">
            <ChipGroup options={taxonomy.languages} selected={form.languages} onToggle={(v) => toggleMulti('languages', v)} />
          </Field>
        )}
      </section>

      <section>
        <h3>Links & rate</h3>
        <div className="grid">
          <Field label="Portfolio / website">
            <input value={form.website_url} onChange={(e) => set('website_url', e.target.value)} placeholder="https://" />
          </Field>
          <Field label="Instagram">
            <input value={form.instagram_url} onChange={(e) => set('instagram_url', e.target.value)} placeholder="https://instagram.com/…" />
          </Field>
          <Field label="Rate from">
            <input type="number" min={0} value={form.rate_min} onChange={(e) => set('rate_min', e.target.value)} />
          </Field>
          <Field label="Rate to">
            <input type="number" min={0} value={form.rate_max} onChange={(e) => set('rate_max', e.target.value)} />
          </Field>
          <Field label="Currency">
            <input value={form.rate_currency} onChange={(e) => set('rate_currency', e.target.value.toUpperCase())} maxLength={3} />
          </Field>
          <Field label="Per">
            <select value={form.rate_unit} onChange={(e) => set('rate_unit', e.target.value)}>
              <option value="hour">Hour</option>
              <option value="day">Day</option>
              <option value="project">Project</option>
            </select>
          </Field>
        </div>
      </section>

      <label className={`checkbox consent ${errors.consent ? 'has-error' : ''}`}>
        <input type="checkbox" checked={form.consent} onChange={(e) => set('consent', e.target.checked)} />
        <span>I agree to be listed in the Blackbook directory and to be contacted about my listing.</span>
      </label>
      {errors.consent && <p className="error-text">{errors.consent}</p>}

      {serverError && <div className="banner error">{serverError}</div>}

      <button className="btn-primary" type="submit" disabled={status === 'submitting'}>
        {status === 'submitting' ? 'Submitting…' : 'Join the directory'}
      </button>
    </form>
  );
}

function Field(props: {
  label: string;
  required?: boolean;
  error?: string;
  children: React.ReactNode;
}) {
  return (
    <label className={`field ${props.error ? 'has-error' : ''}`}>
      <span className="field-label">
        {props.label}
        {props.required && <em aria-hidden> *</em>}
      </span>
      {props.children}
      {props.error && <span className="error-text">{props.error}</span>}
    </label>
  );
}

function ChipGroup(props: {
  options: { value: string; label: string }[];
  selected: string[];
  onToggle: (value: string) => void;
}) {
  return (
    <div className="chips">
      {props.options.map((o) => {
        const active = props.selected.includes(o.value);
        return (
          <button
            key={o.value}
            type="button"
            className={`chip ${active ? 'active' : ''}`}
            aria-pressed={active}
            onClick={() => props.onToggle(o.value)}
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}
