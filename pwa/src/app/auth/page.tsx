<<<<<<< HEAD
"use client";
=======
'use client';
>>>>>>> clean-push

import Link from 'next/link';
import { useState } from 'react';
import { ArrowLeft, Lock, Phone } from 'lucide-react';

export default function AuthPage() {
  const [phone, setPhone] = useState('');
  const [submitted, setSubmitted] = useState(false);

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    setSubmitted(true);
  };

  return (
    <main className="mx-auto flex min-h-screen max-w-3xl items-center justify-center px-4 py-8">
      <div className="w-full rounded-[32px] border border-slate-200 bg-white p-6 shadow-sm sm:p-8">
        <Link href="/" className="flex w-fit items-center gap-2 rounded-full bg-slate-100 px-3 py-2 text-sm text-slate-700">
          <ArrowLeft size={16} /> Back
        </Link>

        <div className="mt-6 flex items-center gap-3">
          <div className="rounded-2xl bg-brand/10 p-3 text-brand">
            <Lock size={22} />
          </div>
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand">Sign in</p>
            <h1 className="text-2xl font-semibold text-slate-900">Access your Winga account</h1>
          </div>
        </div>

        <form onSubmit={handleSubmit} className="mt-6 space-y-4">
          <label className="block text-sm font-medium text-slate-700">
            Mobile number
            <div className="mt-2 flex items-center gap-2 rounded-2xl border border-slate-300 bg-slate-50 px-3 py-3">
              <Phone size={18} className="text-slate-500" />
              <input
                value={phone}
                onChange={(event) => setPhone(event.target.value)}
                placeholder="+255712345678"
                className="w-full bg-transparent outline-none"
              />
            </div>
          </label>

          <button type="submit" className="w-full rounded-2xl bg-brand px-4 py-3 font-medium text-white">
            Continue
          </button>
        </form>

        {submitted ? (
          <p className="mt-4 rounded-2xl bg-emerald-50 p-3 text-sm text-emerald-700">
            Demo mode: the app is ready for OTP-based auth and will connect to Supabase once credentials are configured.
          </p>
        ) : null}
      </div>
    </main>
  );
}
