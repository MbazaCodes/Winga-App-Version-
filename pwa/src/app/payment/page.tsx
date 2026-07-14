import { CreditCard, Wallet } from 'lucide-react';
import FeaturePage from '../components/feature-page';

export default function PaymentPage() {
  return (
    <FeaturePage
      title="Payment"
      description="Handle secure payments and wallet actions in a compact mobile-style screen."
      badge="Payment"
      icon={CreditCard}
    >
      <div className="mt-6 grid gap-3 md:grid-cols-2">
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><CreditCard size={18} /> <span className="font-semibold">Payment methods</span></div>
          <p className="mt-2 text-sm text-slate-600">Add cards, mobile money, and wallet preferences from one screen.</p>
        </div>
        <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
          <div className="flex items-center gap-2 text-brand"><Wallet size={18} /> <span className="font-semibold">Balance</span></div>
          <p className="mt-2 text-sm text-slate-600">Display recent payment success and pending transactions instantly.</p>
        </div>
      </div>
    </FeaturePage>
  );
}
