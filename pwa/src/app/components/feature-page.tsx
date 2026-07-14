import Link from 'next/link';
import type { ReactNode } from 'react';
import type { LucideIcon } from 'lucide-react';
import { ArrowLeft, Sparkles } from 'lucide-react';

type FeaturePageProps = {
  title: string;
  description: string;
  badge?: string;
  icon?: LucideIcon;
  children?: ReactNode;
};

export default function FeaturePage({
  title,
  description,
  badge = 'Feature',
  icon: Icon = Sparkles,
  children,
}: FeaturePageProps) {
  return (
    <main className="mx-auto flex min-h-screen max-w-4xl flex-col px-4 py-6 sm:px-6 lg:px-8">
      <div className="rounded-[32px] border border-slate-200 bg-white p-4 shadow-sm sm:p-6">
        <div className="flex items-center justify-between">
          <Link href="/app" className="flex items-center gap-2 rounded-full bg-slate-100 px-3 py-2 text-sm text-slate-700">
            <ArrowLeft size={16} /> Back
          </Link>
          <div className="rounded-full bg-brand/10 p-2 text-brand">
            <Icon size={18} />
          </div>
        </div>

        <div className="mt-6 rounded-[28px] bg-gradient-to-br from-brand to-emerald-700 p-5 text-white">
          <p className="text-sm uppercase tracking-[0.3em] text-emerald-100">{badge}</p>
          <h1 className="mt-2 text-3xl font-semibold">{title}</h1>
          <p className="mt-2 text-sm text-emerald-50">{description}</p>
        </div>

        {children}
      </div>
    </main>
  );
}
