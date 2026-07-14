import { Headphones, ShieldCheck } from 'lucide-react';
import FeaturePage from '../components/feature-page';

export default function SupportPage() {
  return (
    <FeaturePage
      title="Support"
      description="Offer help, FAQs, and support access in a simple mobile experience."
      badge="Support"
      icon={Headphones}
    >
      <div className="mt-6 grid gap-3 md:grid-cols-2">
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><Headphones size={18} /> <span className="font-semibold">Help center</span></div>
          <p className="mt-2 text-sm text-slate-600">Present common issues and contact options clearly.</p>
        </div>
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><ShieldCheck size={18} /> <span className="font-semibold">Safety</span></div>
          <p className="mt-2 text-sm text-slate-600">Provide safety guidance and emergency contact shortcuts.</p>
        </div>
      </div>
    </FeaturePage>
  );
}
