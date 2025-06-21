#!/usr/bin/env python3
"""
Migrate memories from local Redis Memory Server to centralized instance
"""

import os
import sys
import json
import asyncio
import argparse
from datetime import datetime
import redis
import httpx
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.table import Table

console = Console()

class MemoryMigrator:
    def __init__(self, source_url: str, target_url: str):
        self.source_redis = redis.from_url(source_url)
        self.target_api = target_url
        self.stats = {
            "memories_migrated": 0,
            "sessions_migrated": 0,
            "errors": 0
        }
    
    async def migrate(self):
        """Main migration process"""
        console.print("[bold green]Starting Redis Memory Migration[/bold green]")
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            
            # Step 1: Export memories
            task = progress.add_task("Exporting memories from source...", total=None)
            memories = await self.export_memories()
            progress.update(task, completed=True)
            
            # Step 2: Export sessions
            task = progress.add_task("Exporting sessions from source...", total=None)
            sessions = await self.export_sessions()
            progress.update(task, completed=True)
            
            # Step 3: Import to target
            task = progress.add_task("Importing to central server...", total=len(memories) + len(sessions))
            
            # Import memories
            for memory in memories:
                try:
                    await self.import_memory(memory)
                    self.stats["memories_migrated"] += 1
                except Exception as e:
                    console.print(f"[red]Error migrating memory: {e}[/red]")
                    self.stats["errors"] += 1
                progress.advance(task)
            
            # Import sessions
            for session in sessions:
                try:
                    await self.import_session(session)
                    self.stats["sessions_migrated"] += 1
                except Exception as e:
                    console.print(f"[red]Error migrating session: {e}[/red]")
                    self.stats["errors"] += 1
                progress.advance(task)
        
        # Show results
        self.show_results()
    
    async def export_memories(self):
        """Export all memories from source Redis"""
        memories = []
        cursor = 0
        
        while True:
            cursor, keys = self.source_redis.scan(
                cursor, 
                match="memory:*",
                count=100
            )
            
            for key in keys:
                memory_data = self.source_redis.hgetall(key)
                if memory_data:
                    memories.append({
                        "key": key.decode('utf-8'),
                        "data": {k.decode('utf-8'): v.decode('utf-8') for k, v in memory_data.items()}
                    })
            
            if cursor == 0:
                break
        
        return memories
    
    async def export_sessions(self):
        """Export all sessions from source Redis"""
        sessions = []
        cursor = 0
        
        while True:
            cursor, keys = self.source_redis.scan(
                cursor,
                match="session:*",
                count=100
            )
            
            for key in keys:
                session_data = self.source_redis.get(key)
                if session_data:
                    sessions.append({
                        "key": key.decode('utf-8'),
                        "data": json.loads(session_data)
                    })
            
            if cursor == 0:
                break
        
        return sessions
    
    async def import_memory(self, memory):
        """Import a memory to the target server"""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.target_api}/v1/long-term-memory",
                json={
                    "memories": [{
                        "text": memory["data"].get("text", ""),
                        "memory_type": memory["data"].get("memory_type", "semantic"),
                        "namespace": memory["data"].get("namespace"),
                        "topics": json.loads(memory["data"].get("topics", "[]")),
                        "entities": json.loads(memory["data"].get("entities", "[]")),
                        "id": memory["data"].get("id")
                    }]
                },
                timeout=30.0
            )
            response.raise_for_status()
    
    async def import_session(self, session):
        """Import a session to the target server"""
        async with httpx.AsyncClient() as client:
            session_id = session["key"].split(":")[-1]
            response = await client.put(
                f"{self.target_api}/v1/working-memory/{session_id}",
                json=session["data"],
                timeout=30.0
            )
            response.raise_for_status()
    
    def show_results(self):
        """Display migration results"""
        table = Table(title="Migration Results")
        table.add_column("Metric", style="cyan")
        table.add_column("Count", style="green")
        
        table.add_row("Memories Migrated", str(self.stats["memories_migrated"]))
        table.add_row("Sessions Migrated", str(self.stats["sessions_migrated"]))
        table.add_row("Errors", str(self.stats["errors"]))
        table.add_row("Total Items", str(
            self.stats["memories_migrated"] + self.stats["sessions_migrated"]
        ))
        
        console.print("\n")
        console.print(table)
        
        if self.stats["errors"] > 0:
            console.print("\n[yellow]⚠️  Migration completed with errors. Please review logs.[/yellow]")
        else:
            console.print("\n[green]✅ Migration completed successfully![/green]")


async def main():
    parser = argparse.ArgumentParser(
        description="Migrate Redis Memory Server data to centralized instance"
    )
    parser.add_argument(
        "--source",
        default="redis://localhost:16379",
        help="Source Redis URL (default: redis://localhost:16379)"
    )
    parser.add_argument(
        "--target",
        default="http://10.10.20.85:8000",
        help="Target API URL (default: http://10.10.20.85:8000)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be migrated without actually migrating"
    )
    
    args = parser.parse_args()
    
    # Create backup warning
    console.print("[bold yellow]⚠️  WARNING: Migration will modify the target server![/bold yellow]")
    console.print("Please ensure you have a backup before proceeding.\n")
    
    if not args.dry_run:
        confirm = console.input("Continue with migration? [y/N]: ")
        if confirm.lower() != 'y':
            console.print("[red]Migration cancelled.[/red]")
            sys.exit(0)
    
    # Run migration
    migrator = MemoryMigrator(args.source, args.target)
    await migrator.migrate()


if __name__ == "__main__":
    asyncio.run(main())