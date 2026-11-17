<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class StatsTest extends TestCase
{
    public function test_health_returns_ok(): void
    {
        $response = $this->getJson('/health');

        $response->assertStatus(200)
                 ->assertJsonFragment(['status' => 'ok']);
    }

    public function test_stats_returns_expected_keys(): void
    {
        // Mock DB::selectOne to return fake data
        DB::shouldReceive('selectOne')
            ->times(4)
            ->andReturnValues([
                (object) ['total_orders' => 10],
                (object) ['pending_orders' => 3],
                (object) ['completed_orders' => 7],
                (object) ['total_revenue' => 12500.00],
            ]);

        $response = $this->getJson('/stats');

        $response->assertStatus(200)
                 ->assertJsonStructure([
                     'total_orders',
                     'pending_orders',
                     'completed_orders',
                     'total_revenue',
                 ]);
    }
}
