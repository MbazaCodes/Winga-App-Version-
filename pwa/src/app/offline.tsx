export default function OfflinePage() {
  return (
    <main className="flex min-h-screen items-center justify-center px-4">
      <div className="rounded-3xl border border-slate-200 bg-white p-8 text-center shadow-sm">
        <h1 className="text-2xl font-semibold text-slate-900">You’re offline</h1>
        <p className="mt-2 text-slate-600">The Winga app shell is still available, and the latest content will sync when you reconnect.</p>
      </div>
    </main>
  );
}
