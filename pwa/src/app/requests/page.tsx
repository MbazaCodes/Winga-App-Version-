import { BellRing, ListChecks } from 'lucide-react';
import FeaturePage from '../components/feature-page';

export default function RequestsPage() {
  return (
    <FeaturePage
      title="Requests"
      description="Display ride requests and live status updates with a touch-friendly layout."
      badge="Requests"
      icon={ListChecks}
    >
      <div className="mt-6 grid gap-3 md:grid-cols-2">
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><ListChecks size={18} /> <span className="font-semibold">Active requests</span></div>
          <p className="mt-2 text-sm text-slate-600">List request status from pending to completed.</p>
        </div>
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><BellRing size={18} /> <span className="font-semibold">Updates</span></div>
          <p className="mt-2 text-sm text-slate-600">Show notifications and real-time status changes.</p>
        </div>
      </div>
    </FeaturePage>
  );
}
