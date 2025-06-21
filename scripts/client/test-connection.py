#!/usr/bin/env python3
"""
Test connection to centralized Redis Memory Server
Validates all endpoints and functionality
"""

import os
import sys
import json
import time
import asyncio
import httpx
import redis
from datetime import datetime
from rich.console import Console
from rich.table import Table
from rich.progress import track
from rich.panel import Panel

console = Console()

class ConnectionTester:
    def __init__(self, server_ip: str = None):
        self.server_ip = server_ip or os.getenv("REDIS_MEMORY_IP", "10.10.20.85")
        self.api_url = f"http://{self.server_ip}:8000"
        self.mcp_url = f"http://{self.server_ip}:9000"
        self.redis_url = f"redis://{self.server_ip}:16379"
        self.results = []
    
    async def run_all_tests(self):
        """Run all connection tests"""
        console.print(Panel.fit(
            f"[bold blue]Redis Memory Central Connection Test[/bold blue]\n"
            f"Server: {self.server_ip}",
            padding=(1, 2)
        ))
        
        tests = [
            ("Redis Connection", self.test_redis),
            ("API Health", self.test_api_health),
            ("API Authentication", self.test_api_auth),
            ("Create Memory", self.test_create_memory),
            ("Search Memory", self.test_search_memory),
            ("Working Memory", self.test_working_memory),
            ("MCP Server", self.test_mcp),
            ("Performance", self.test_performance)
        ]
        
        for name, test_func in track(tests, description="Running tests..."):
            try:
                result = await test_func()
                self.results.append({
                    "test": name,
                    "status": "✅ PASS" if result["success"] else "❌ FAIL",
                    "message": result["message"],
                    "duration": result.get("duration", "N/A")
                })
            except Exception as e:
                self.results.append({
                    "test": name,
                    "status": "❌ ERROR",
                    "message": str(e),
                    "duration": "N/A"
                })
        
        self.display_results()
    
    async def test_redis(self):
        """Test Redis connection"""
        start = time.time()
        try:
            r = redis.from_url(self.redis_url)
            pong = r.ping()
            info = r.info()
            duration = time.time() - start
            
            return {
                "success": pong,
                "message": f"Redis {info['redis_version']} - Memory: {info['used_memory_human']}",
                "duration": f"{duration:.2f}s"
            }
        except Exception as e:
            return {
                "success": False,
                "message": f"Connection failed: {e}",
                "duration": f"{time.time() - start:.2f}s"
            }
    
    async def test_api_health(self):
        """Test API health endpoint"""
        start = time.time()
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(f"{self.api_url}/v1/health")
                response.raise_for_status()
                data = response.json()
                duration = time.time() - start
                
                return {
                    "success": data.get("status") == "healthy",
                    "message": f"API {data.get('version', 'unknown')} - Redis: {data.get('redis_connected')}",
                    "duration": f"{duration:.2f}s"
                }
            except Exception as e:
                return {
                    "success": False,
                    "message": f"Health check failed: {e}",
                    "duration": f"{time.time() - start:.2f}s"
                }
    
    async def test_api_auth(self):
        """Test API authentication status"""
        start = time.time()
        async with httpx.AsyncClient() as client:
            try:
                # Try to access without auth
                response = await client.get(f"{self.api_url}/v1/working-memory")
                duration = time.time() - start
                
                if response.status_code == 200:
                    return {
                        "success": True,
                        "message": "Authentication disabled (dev mode)",
                        "duration": f"{duration:.2f}s"
                    }
                elif response.status_code == 401:
                    return {
                        "success": True,
                        "message": "Authentication enabled (production mode)",
                        "duration": f"{duration:.2f}s"
                    }
                else:
                    return {
                        "success": False,
                        "message": f"Unexpected status: {response.status_code}",
                        "duration": f"{duration:.2f}s"
                    }
            except Exception as e:
                return {
                    "success": False,
                    "message": f"Auth test failed: {e}",
                    "duration": f"{time.time() - start:.2f}s"
                }
    
    async def test_create_memory(self):
        """Test creating a long-term memory"""
        start = time.time()
        async with httpx.AsyncClient() as client:
            try:
                test_memory = {
                    "memories": [{
                        "id": f"test_memory_{int(time.time())}",
                        "text": "Connection test memory from client",
                        "memory_type": "semantic",
                        "namespace": "test",
                        "topics": ["connection", "test"],
                        "entities": ["Redis Memory Central"]
                    }]
                }
                
                response = await client.post(
                    f"{self.api_url}/v1/long-term-memory",
                    json=test_memory,
                    timeout=10.0
                )
                response.raise_for_status()
                duration = time.time() - start
                
                return {
                    "success": True,
                    "message": f"Created memory ID: {test_memory['memories'][0]['id']}",
                    "duration": f"{duration:.2f}s"
                }
            except Exception as e:
                return {
                    "success": False,
                    "message": f"Create failed: {e}",
                    "duration": f"{time.time() - start:.2f}s"
                }
    
    async def test_search_memory(self):
        """Test searching memories"""
        start = time.time()
        async with httpx.AsyncClient() as client:
            try:
                search_query = {
                    "text": "connection test",
                    "limit": 5,
                    "namespace": {"eq": "test"}
                }
                
                response = await client.post(
                    f"{self.api_url}/v1/long-term-memory/search",
                    json=search_query,
                    timeout=10.0
                )
                response.raise_for_status()
                data = response.json()
                duration = time.time() - start
                
                count = len(data.get("results", []))
                return {
                    "success": True,
                    "message": f"Found {count} memories matching 'connection test'",
                    "duration": f"{duration:.2f}s"
                }
            except Exception as e:
                return {
                    "success": False,
                    "message": f"Search failed: {e}",
                    "duration": f"{time.time() - start:.2f}s"
                }
    
    async def test_working_memory(self):
        """Test working memory operations"""
        start = time.time()
        session_id = f"test_session_{int(time.time())}"
        
        async with httpx.AsyncClient() as client:
            try:
                # Create session
                session_data = {
                    "messages": [
                        {"role": "user", "content": "Test message"},
                        {"role": "assistant", "content": "Test response"}
                    ],
                    "context": "Connection test context",
                    "memories": [{
                        "text": "Test working memory",
                        "memory_type": "message"
                    }]
                }
                
                response = await client.put(
                    f"{self.api_url}/v1/working-memory/{session_id}",
                    json=session_data,
                    timeout=10.0
                )
                response.raise_for_status()
                
                # Read it back
                response = await client.get(
                    f"{self.api_url}/v1/working-memory/{session_id}",
                    timeout=10.0
                )
                response.raise_for_status()
                duration = time.time() - start
                
                return {
                    "success": True,
                    "message": f"Session {session_id} created and retrieved",
                    "duration": f"{duration:.2f}s"
                }
            except Exception as e:
                return {
                    "success": False,
                    "message": f"Working memory test failed: {e}",
                    "duration": f"{time.time() - start:.2f}s"
                }
    
    async def test_mcp(self):
        """Test MCP server connection"""
        start = time.time()
        async with httpx.AsyncClient() as client:
            try:
                # MCP servers typically respond to specific JSON-RPC requests
                mcp_request = {
                    "jsonrpc": "2.0",
                    "method": "initialize",
                    "params": {
                        "protocolVersion": "2024-11-05",
                        "clientInfo": {
                            "name": "connection-test",
                            "version": "1.0.0"
                        }
                    },
                    "id": 1
                }
                
                response = await client.post(
                    self.mcp_url,
                    json=mcp_request,
                    timeout=10.0
                )
                duration = time.time() - start
                
                if response.status_code == 200:
                    return {
                        "success": True,
                        "message": "MCP server responding to JSON-RPC",
                        "duration": f"{duration:.2f}s"
                    }
                else:
                    return {
                        "success": True,
                        "message": f"MCP server running (status: {response.status_code})",
                        "duration": f"{duration:.2f}s"
                    }
            except Exception as e:
                return {
                    "success": False,
                    "message": f"MCP connection failed: {e}",
                    "duration": f"{time.time() - start:.2f}s"
                }
    
    async def test_performance(self):
        """Test performance with multiple operations"""
        start = time.time()
        latencies = []
        
        async with httpx.AsyncClient() as client:
            try:
                # Run 10 quick operations
                for i in range(10):
                    op_start = time.time()
                    response = await client.get(
                        f"{self.api_url}/v1/health",
                        timeout=5.0
                    )
                    response.raise_for_status()
                    latencies.append((time.time() - op_start) * 1000)  # ms
                
                avg_latency = sum(latencies) / len(latencies)
                min_latency = min(latencies)
                max_latency = max(latencies)
                duration = time.time() - start
                
                return {
                    "success": avg_latency < 100,  # Target < 100ms
                    "message": f"Avg: {avg_latency:.1f}ms, Min: {min_latency:.1f}ms, Max: {max_latency:.1f}ms",
                    "duration": f"{duration:.2f}s"
                }
            except Exception as e:
                return {
                    "success": False,
                    "message": f"Performance test failed: {e}",
                    "duration": f"{time.time() - start:.2f}s"
                }
    
    def display_results(self):
        """Display test results in a table"""
        table = Table(title="\nTest Results", show_lines=True)
        table.add_column("Test", style="cyan", width=20)
        table.add_column("Status", width=12)
        table.add_column("Message", style="white")
        table.add_column("Duration", style="yellow", width=10)
        
        for result in self.results:
            style = "green" if "PASS" in result["status"] else "red"
            table.add_row(
                result["test"],
                f"[{style}]{result['status']}[/{style}]",
                result["message"],
                result["duration"]
            )
        
        console.print(table)
        
        # Summary
        passed = sum(1 for r in self.results if "PASS" in r["status"])
        total = len(self.results)
        
        if passed == total:
            console.print(f"\n[bold green]✅ All tests passed! ({passed}/{total})[/bold green]")
            console.print("\n🎉 Your Redis Memory Central server is fully operational!")
        else:
            console.print(f"\n[bold yellow]⚠️  {passed}/{total} tests passed[/bold yellow]")
            console.print("\nPlease check the failed tests and ensure all services are running.")
        
        # Connection info
        console.print("\n[bold]Connection Information:[/bold]")
        console.print(f"  Server IP: {self.server_ip}")
        console.print(f"  API URL: {self.api_url}")
        console.print(f"  MCP URL: {self.mcp_url}")
        console.print(f"  Redis URL: {self.redis_url}")


async def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Test connection to Redis Memory Central server"
    )
    parser.add_argument(
        "--server",
        default=os.getenv("REDIS_MEMORY_IP", "10.10.20.85"),
        help="Server IP address (default: 10.10.20.85)"
    )
    
    args = parser.parse_args()
    
    tester = ConnectionTester(args.server)
    await tester.run_all_tests()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        console.print("\n[yellow]Test interrupted by user[/yellow]")
        sys.exit(1)
    except Exception as e:
        console.print(f"\n[red]Error: {e}[/red]")
        sys.exit(1)