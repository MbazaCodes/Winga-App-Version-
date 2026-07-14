import { CalendarClock, MapPin, Sparkles } from 'lucide-react';
import FeaturePage from '../components/feature-page';

export default function BookingPage() {
  return (
    <FeaturePage
      title="Booking"
      description="Create and review ride requests with the same structure as the mobile flow."
      badge="Booking"
      icon={MapPin}
    >
      <div className="mt-6 grid gap-3 md:grid-cols-2">
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><CalendarClock size={18} /> <span className="font-semibold">Scheduled ride</span></div>
          <p className="mt-2 text-sm text-slate-600">Select a pickup window and share your route details in seconds.</p>
        </div>
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><Sparkles size={18} /> <span className="font-semibold">Smart matching</span></div>
          <p className="mt-2 text-sm text-slate-600">The app is ready to connect to booking services and live ride matching.</p>
        </div>
      </div>
    </FeaturePage>
  );
}
