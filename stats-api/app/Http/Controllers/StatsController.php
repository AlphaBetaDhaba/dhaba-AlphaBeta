<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class StatsController extends Controller
{
    public function index(): JsonResponse
    {
        $totalOrders = DB::selectOne('SELECT COUNT(*) as total_orders FROM orders');
        $pendingOrders = DB::selectOne("SELECT COUNT(*) as pending_orders FROM orders WHERE status IN ('new','cooking')");
        $completedOrders = DB::selectOne("SELECT COUNT(*) as completed_orders FROM orders WHERE status = 'ready'");
        $totalRevenue = DB::selectOne("SELECT COALESCE(SUM(total_amount), 0) as total_revenue FROM orders");

        return response()->json([
            'total_orders'     => (int) $totalOrders->total_orders,
            'pending_orders'   => (int) $pendingOrders->pending_orders,
            'completed_orders' => (int) $completedOrders->completed_orders,
            'total_revenue'    => (float) $totalRevenue->total_revenue,
        ]);
    }
}
