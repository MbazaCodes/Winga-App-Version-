import { Search, Filter, Download } from 'lucide-react';
import { getRequests } from './requests-data';

const requests = [
  { id: 'REQ-1042', client: 'Mariam', status: 'Pending', amount: '$150' },
  { id: 'REQ-1043', client: 'John', status: 'Approved', amount: '$320' },
  { id: 'REQ-1044', client: 'Tina', status: 'Review', amount: '$80' },
];

export default async function RequestsPage() {
  const data = await getRequests().catch(() => []);
  const rows = data.length > 0 ? data : requests;

  return (
    <main className="space-y-6">
      <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
        <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <h1 className="text-2xl font-semibold text-slate-900">Requests</h1>
            <p className="mt-1 text-sm text-slate-500">Manage incoming bookings and operator review queues.</p>
          </div>
          <div className="flex items-center gap-2">
            <button className="rounded-xl border border-slate-200 px-3 py-2 text-sm text-slate-600">
              <Filter size={16} className="mr-2 inline" />Filter
            </button>
            <button className="rounded-xl bg-primary px-3 py-2 text-sm text-white">
              <Download size={16} className="mr-2 inline" />Export
            </button>
          </div>
        </div>

        <div className="mt-6 flex items-center gap-3 rounded-2xl border border-slate-200 bg-slate-50 px-3 py-2">
          <Search size={16} className="text-slate-400" />
          <input className="w-full bg-transparent text-sm outline-none" placeholder="Search requests" />
        </div>
      </div>

      <div className="overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-sm">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50 text-left text-slate-600">
            <tr>
              <th className="px-4 py-3 font-medium">Request ID</th>
              <th className="px-4 py-3 font-medium">Client</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Amount</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {rows.map((request: any) => (
              <tr key={request.id} className="hover:bg-slate-50">
                <td className="px-4 py-3">{request.id}</td>
                <td className="px-4 py-3">{request.client_name || request.customer_id || 'Unknown'}</td>
                <td className="px-4 py-3">
                  <span className="rounded-full bg-amber-100 px-2.5 py-1 text-xs font-semibold text-amber-700">{request.status || 'Pending'}</span>
                </td>
                <td className="px-4 py-3">{request.total_price ? `$${request.total_price}` : request.amount}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </main>
  );
}
