'use client';

import Link from 'next/link';
import { useState } from 'react';
<<<<<<< HEAD
import { ArrowLeft, Bell, CarFront, Clock3, CreditCard, Headphones, MapPin, Send, UserRound } from 'lucide-react';
import { supabase } from '../../lib/supabase';
=======
import { ArrowLeft, Bell, Clock3, CreditCard, MapPin, Send, UserRound } from 'lucide-react';
>>>>>>> clean-push

export default function AppPage() {
  const [pickup, setPickup] = useState('Julius Nyerere International Airport');
  const [dropoff, setDropoff] = useState('Dar es Salaam City Center');
  const [status, setStatus] = useState<'idle' | 'saving' | 'success' | 'error'>('idle');
  const [message, setMessage] = useState('');

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setStatus('saving');
    setMessage('');
<<<<<<< HEAD

    try {
      const { error } = await supabase.from('requests').insert({
        pickup_location: pickup,
        dropoff_location: dropoff,
        status: 'pending',
      });

      if (error) throw error;

      setStatus('success');
      setMessage('Booking created successfully.');
    } catch (error) {
      setStatus('error');
      setMessage('Could not create booking right now.');
    }
=======
    setTimeout(() => {
      setStatus('success');
      setMessage('Booking created successfully.');
    }, 500);
>>>>>>> clean-push
  };

  return (
    <main className="mx-auto flex min-h-screen max-w-4xl flex-col px-4 py-6 sm:px-6 lg:px-8">
      <div className="rounded-[32px] border border-slate-200 bg-white p-4 shadow-sm">
        <div className="flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2 rounded-full bg-slate-100 px-3 py-2 text-sm text-slate-700">
            <ArrowLeft size={16} /> Back
          </Link>
          <div className="rounded-full bg-brand/10 p-2 text-brand">
            <Bell size={18} />
          </div>
        </div>

        <div className="mt-6 rounded-[28px] bg-gradient-to-br from-brand to-emerald-700 p-5 text-white">
          <p className="text-sm uppercase tracking-[0.3em] text-emerald-100">Welcome back</p>
          <h1 className="mt-2 text-3xl font-semibold">Book your next ride</h1>
          <p className="mt-2 text-sm text-emerald-50">Fast, reliable, and installable on iPhone and Android.</p>
        </div>

        <form onSubmit={handleSubmit} className="mt-6 space-y-4 rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div>
            <label className="mb-2 block text-sm font-medium text-slate-700">Pickup</label>
            <input
              value={pickup}
              onChange={(event) => setPickup(event.target.value)}
              className="w-full rounded-2xl border border-slate-300 bg-white px-3 py-3 outline-none"
              placeholder="Pickup location"
            />
          </div>
          <div>
            <label className="mb-2 block text-sm font-medium text-slate-700">Drop-off</label>
            <input
              value={dropoff}
              onChange={(event) => setDropoff(event.target.value)}
              className="w-full rounded-2xl border border-slate-300 bg-white px-3 py-3 outline-none"
              placeholder="Drop-off location"
            />
          </div>
          <button type="submit" className="flex w-full items-center justify-center gap-2 rounded-2xl bg-brand px-4 py-3 font-medium text-white">
            <Send size={18} /> {status === 'saving' ? 'Creating booking...' : 'Create booking'}
          </button>
          {message ? (
            <p className={`text-sm ${status === 'success' ? 'text-emerald-700' : 'text-rose-700'}`}>{message}</p>
          ) : null}
        </form>

<<<<<<< HEAD
        <div className="mt-6 grid gap-3 sm:grid-cols-2">
          <Link href="/booking" className="rounded-2xl border border-slate-200 bg-slate-50 p-4 transition hover:border-brand">
            <div className="flex items-center gap-2"><MapPin className="text-brand" size={18} /> <span className="font-semibold">Request ride</span></div>
            <p className="mt-2 text-sm text-slate-600">Start a pickup request from anywhere.</p>
          </Link>
          <Link href="/tracking" className="rounded-2xl border border-slate-200 bg-slate-50 p-4 transition hover:border-brand">
            <div className="flex items-center gap-2"><Clock3 className="text-brand" size={18} /> <span className="font-semibold">Track status</span></div>
            <p className="mt-2 text-sm text-slate-600">Follow ETA and driver updates.</p>
          </Link>
          <Link href="/payment" className="rounded-2xl border border-slate-200 bg-slate-50 p-4 transition hover:border-brand">
            <div className="flex items-center gap-2"><CreditCard className="text-brand" size={18} /> <span className="font-semibold">Pay securely</span></div>
            <p className="mt-2 text-sm text-slate-600">Use mobile money and cards with confidence.</p>
          </Link>
          <Link href="/profile" className="rounded-2xl border border-slate-200 bg-slate-50 p-4 transition hover:border-brand">
            <div className="flex items-center gap-2"><UserRound className="text-brand" size={18} /> <span className="font-semibold">Manage profile</span></div>
            <p className="mt-2 text-sm text-slate-600">Save favourites and ride history.</p>
          </Link>
          <Link href="/driver" className="rounded-2xl border border-slate-200 bg-slate-50 p-4 transition hover:border-brand">
            <div className="flex items-center gap-2"><CarFront className="text-brand" size={18} /> <span className="font-semibold">Driver mode</span></div>
            <p className="mt-2 text-sm text-slate-600">Switch to driver workflows and availability.</p>
          </Link>
          <Link href="/support" className="rounded-2xl border border-slate-200 bg-slate-50 p-4 transition hover:border-brand">
            <div className="flex items-center gap-2"><Headphones className="text-brand" size={18} /> <span className="font-semibold">Support</span></div>
            <p className="mt-2 text-sm text-slate-600">Get help and safety information quickly.</p>
          </Link>
        </div>
=======
>>>>>>> clean-push
      </div>
    </main>
  );
}
