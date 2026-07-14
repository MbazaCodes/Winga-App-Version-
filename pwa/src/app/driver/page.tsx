import { CarFront, ShieldCheck } from 'lucide-react';
import FeaturePage from '../components/feature-page';

export default function DriverPage() {
  return (
    <FeaturePage
      title="Driver"
      description="Monitor driver status, profile information, and trip readiness in a mobile-style dashboard."
      badge="Driver"
      icon={CarFront}
    >
      <div className="mt-6 grid gap-3 md:grid-cols-2">
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><CarFront size={18} /> <span className="font-semibold">Availability</span></div>
          <p className="mt-2 text-sm text-slate-600">Switch between online and offline states from a single tap.</p>
        </div>
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><ShieldCheck size={18} /> <span className="font-semibold">Verification</span></div>
          <p className="mt-2 text-sm text-slate-600">Secure onboarding and document checks can be surfaced here.</p>
        </div>
      </div>
    </FeaturePage>
  );
}
