import Link from 'next/link';
import { Bell, LayoutGrid, ShieldCheck, Users, Wallet, Receipt, Star, MessageSquare } from 'lucide-react';

const navItems = [
  { href: '/', label: 'Dashboard', icon: LayoutGrid },
  { href: '/requests', label: 'Requests', icon: ShieldCheck },
  { href: '/wingas', label: 'Wingas', icon: Users },
  { href: '/clients', label: 'Clients', icon: Users },
  { href: '/earnings', label: 'Earnings', icon: Wallet },
  { href: '/transactions', label: 'Transactions', icon: Receipt },
  { href: '/ratings', label: 'Ratings', icon: Star },
  { href: '/notifications', label: 'Notifications', icon: Bell },
];

export function AdminShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen bg-slate-50">
      <aside className="hidden w-72 flex-col border-r border-slate-200 bg-white p-6 lg:flex">
        <div className="mb-8">
          <p className="text-sm font-semibold uppercase tracking-[0.3em] text-primary">Winga</p>
          <h2 className="mt-2 text-xl font-semibold text-slate-900">Admin V3</h2>
        </div>

        <nav className="space-y-2">
          {navItems.map((item) => {
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                className="flex items-center gap-3 rounded-xl px-3 py-3 text-sm font-medium text-slate-600 transition hover:bg-slate-100 hover:text-slate-900"
              >
                <Icon size={16} />
                {item.label}
              </Link>
            );
          })}
        </nav>
      </aside>

      <main className="flex-1 p-6 lg:p-8">
        <div className="mx-auto max-w-7xl">{children}</div>
      </main>
    </div>
  );
}
