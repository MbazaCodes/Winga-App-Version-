import Link from 'next/link';
import { ArrowUpRight, DollarSign, LayoutGrid, Users, Wallet } from 'lucide-react';
import { supabase } from '../lib/supabase';

async function getStats() {
  const [{ count: requestsCount }, { count: usersCount }] = await Promise.all([
    supabase.from('requests').select('*', { count: 'exact', head: true }),
    supabase.from('users').select('*', { count: 'exact', head: true }),
  ]);

  return {
    requests: requestsCount ?? 0,
    users: usersCount ?? 0,
  };
}

export default async function DashboardPage() {
  const stats = await getStats().catch(() => ({ requests: 0, users: 0 }));

  return (
    <main className="space-y-8">
      <div className="flex flex-col gap-4 rounded-3xl border border-slate-200 bg-white p-8 shadow-sm md:flex-row md:items-center md:justify-between">
        <div>
          <p className="text-sm font-semibold uppercase tracking-[0.3em] text-primary">Admin Console</p>
          <h1 className="mt-2 text-3xl font-semibold text-slate-900">Winga Dashboard</h1>
          <p className="mt-2 text-sm text-slate-500">Live counts from the original Winga App schema.</p>
        </div>
        <Link href="/requests" className="inline-flex items-center gap-2 rounded-xl bg-primary px-4 py-2 text-white">
          Review requests <ArrowUpRight size={16} />
        </Link>
      </div>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <div className="flex items-center justify-between"><p className="text-sm text-slate-500">Active Requests</p><LayoutGrid className="text-primary" size={18} /></div>
          <p className="mt-4 text-3xl font-semibold text-slate-900">{stats.requests}</p>
        </div>
        <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <div className="flex items-center justify-between"><p className="text-sm text-slate-500">Clients</p><Users className="text-primary" size={18} /></div>
          <p className="mt-4 text-3xl font-semibold text-slate-900">{stats.users}</p>
        </div>
        <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <div className="flex items-center justify-between"><p className="text-sm text-slate-500">Revenue</p><DollarSign className="text-primary" size={18} /></div>
          <p className="mt-4 text-3xl font-semibold text-slate-900">$84k</p>
        </div>
        <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <div className="flex items-center justify-between"><p className="text-sm text-slate-500">Payouts</p><Wallet className="text-primary" size={18} /></div>
          <p className="mt-4 text-3xl font-semibold text-slate-900">$21k</p>
        </div>
      </div>

      <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
        <h2 className="text-xl font-semibold">Operations overview</h2>
        <p className="mt-2 text-sm text-slate-500">The admin console now uses the same Supabase-backed schema as the original Winga App.</p>
      </div>
    </main>
  );
}
