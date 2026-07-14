import { UserRound, Sparkles } from 'lucide-react';
import FeaturePage from '../components/feature-page';

export default function ProfilePage() {
  return (
    <FeaturePage
      title="Profile"
      description="Show account details, preferences, and preferences in a mobile-friendly profile layout."
      badge="Profile"
      icon={UserRound}
    >
      <div className="mt-6 grid gap-3 md:grid-cols-2">
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><UserRound size={18} /> <span className="font-semibold">Account</span></div>
          <p className="mt-2 text-sm text-slate-600">Display name, phone number, and saved addresses clearly.</p>
        </div>
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><Sparkles size={18} /> <span className="font-semibold">Preferences</span></div>
          <p className="mt-2 text-sm text-slate-600">Allow toggles for notifications, safety, and ride preferences.</p>
        </div>
      </div>
    </FeaturePage>
  );
}
