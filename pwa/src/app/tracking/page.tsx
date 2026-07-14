import { MapPinned, Radio } from 'lucide-react';
import FeaturePage from '../components/feature-page';

export default function TrackingPage() {
  return (
    <FeaturePage
      title="Tracking"
      description="Track trips and route progress with a dedicated live map-style view."
      badge="Tracking"
      icon={MapPinned}
    >
      <div className="mt-6 grid gap-3 md:grid-cols-2">
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><MapPinned size={18} /> <span className="font-semibold">Live route</span></div>
          <p className="mt-2 text-sm text-slate-600">Display progress along the pickup and drop-off journey.</p>
        </div>
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><Radio size={18} /> <span className="font-semibold">Live status</span></div>
          <p className="mt-2 text-sm text-slate-600">Share driver arrival, trip start, and completed status updates.</p>
        </div>
      </div>
    </FeaturePage>
  );
}
