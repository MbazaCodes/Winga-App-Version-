import { Clock3, ListChecks } from 'lucide-react';
import FeaturePage from '../components/feature-page';

export default function HistoryPage() {
  return (
    <FeaturePage
      title="History"
      description="Review completed rides and see trip summaries in a familiar mobile timeline."
      badge="History"
      icon={Clock3}
    >
      <div className="mt-6 grid gap-3 md:grid-cols-2">
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><Clock3 size={18} /> <span className="font-semibold">Recent rides</span></div>
          <p className="mt-2 text-sm text-slate-600">A compact history view can display recent pickup and drop-off activity.</p>
        </div>
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><ListChecks size={18} /> <span className="font-semibold">Trip summary</span></div>
          <p className="mt-2 text-sm text-slate-600">Details such as fare, distance, and payment status can be added here.</p>
        </div>
      </div>
    </FeaturePage>
  );
}
