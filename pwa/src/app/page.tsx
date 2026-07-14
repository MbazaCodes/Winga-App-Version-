import Link from 'next/link';
import { ArrowRight, MapPin, ShieldCheck, Smartphone } from 'lucide-react';

const cards = [
  { title: 'Book a ride', description: 'Create a booking in a few taps with a mobile-first flow.', icon: MapPin },
  { title: 'Track status', description: 'Follow request status, ETA, and driver updates in real time.', icon: Smartphone },
  { title: 'Secure payments', description: 'Pay with mobile money and see every step clearly.', icon: ShieldCheck },
];

export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-5xl flex-col justify-center px-4 py-8 sm:px-6 lg:px-8">
      <section className="rounded-[32px] border border-slate-200 bg-white p-6 shadow-sm sm:p-8">
        <div className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
          <div className="max-w-2xl">
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand">Winga PWA</p>
            <h1 className="mt-3 text-4xl font-semibold text-slate-900 sm:text-5xl">A mobile-first experience for customers and Winga agents.</h1>
            <p className="mt-4 text-lg text-slate-600">This Progressive Web App mirrors the Flutter app experience so users can install it on iPhone, Android, and desktop without downloading an APK.</p>
          </div>
          <div className="flex flex-wrap gap-3">
            <Link href="/auth" className="inline-flex items-center justify-center gap-2 rounded-2xl border border-slate-300 px-5 py-3 text-slate-700">
              Sign in
            </Link>
            <Link href="/app" className="inline-flex items-center justify-center gap-2 rounded-2xl bg-brand px-5 py-3 text-white">
              Open app <ArrowRight size={18} />
            </Link>
          </div>
        </div>

        <div className="mt-8 grid gap-4 md:grid-cols-3">
          {cards.map((card) => {
            const Icon = card.icon;
            return (
              <div key={card.title} className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
                <Icon className="text-brand" size={22} />
                <h2 className="mt-3 text-lg font-semibold text-slate-900">{card.title}</h2>
                <p className="mt-2 text-sm text-slate-600">{card.description}</p>
              </div>
            );
          })}
        </div>
      </section>
    </main>
  );
}
