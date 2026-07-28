import discord
from discord.ext import commands
from discord import app_commands
import json
import os
from datetime import timedelta

intents = discord.Intents.all()
bot = commands.Bot(command_prefix='!', intents=intents)

# ========================
# XP SYSTEM
# ========================
xp_data = {}
XP_FILE = "xp_data.json"

def load_xp():
    global xp_data
    if os.path.exists(XP_FILE):
        with open(XP_FILE, 'r') as f:
            xp_data = json.load(f)

def save_xp():
    with open(XP_FILE, 'w') as f:
        json.dump(xp_data, f)

def get_level(xp):
    return int(xp ** 0.5 // 10)

# ========================
# WELCOME CONFIG
# ========================
welcome_channels = {}
WELCOME_FILE = "welcome.json"

def load_welcome():
    global welcome_channels
    if os.path.exists(WELCOME_FILE):
        with open(WELCOME_FILE, 'r') as f:
            welcome_channels = json.load(f)

def save_welcome():
    with open(WELCOME_FILE, 'w') as f:
        json.dump(welcome_channels, f)

# ========================
# EVENTS
# ========================
@bot.event
async def on_ready():
    load_xp()
    load_welcome()
    await bot.tree.sync()
    print(f'✅ Connecté : {bot.user}')
    await bot.change_presence(activity=discord.Activity(
        type=discord.ActivityType.watching,
        name="le serveur 👀"
    ))

@bot.event
async def on_member_join(member):
    guild_id = str(member.guild.id)
    if guild_id in welcome_channels:
        channel = bot.get_channel(int(welcome_channels[guild_id]))
        if channel:
            embed = discord.Embed(
                title=f"👋 Bienvenue {member.name} !",
                description=f"Tu es le **{member.guild.member_count}ème** membre !\nPasse un bon séjour sur **{member.guild.name}** !",
                color=discord.Color.green()
            )
            if member.avatar:
                embed.set_thumbnail(url=member.avatar.url)
            embed.set_footer(text=f"ID: {member.id}")
            await channel.send(embed=embed)

@bot.event
async def on_message(message):
    if message.author.bot or not message.guild:
        return
    guild_id = str(message.guild.id)
    user_id = str(message.author.id)
    if guild_id not in xp_data:
        xp_data[guild_id] = {}
    if user_id not in xp_data[guild_id]:
        xp_data[guild_id][user_id] = {"xp": 0, "level": 0}
    xp_data[guild_id][user_id]["xp"] += 5
    current_xp = xp_data[guild_id][user_id]["xp"]
    new_level = get_level(current_xp)
    if new_level > xp_data[guild_id][user_id]["level"]:
        xp_data[guild_id][user_id]["level"] = new_level
        embed = discord.Embed(
            title="🎉 Level Up !",
            description=f"{message.author.mention} vient de passer **niveau {new_level}** !",
            color=discord.Color.gold()
        )
        await message.channel.send(embed=embed)
    save_xp()
    await bot.process_commands(message)

# ========================
# GÉNÉRAL
# ========================
@bot.tree.command(name="help", description="Affiche toutes les commandes")
async def help_cmd(interaction: discord.Interaction):
    embed = discord.Embed(title="📋 Commandes disponibles", color=discord.Color.blue())
    embed.add_field(name="🎮 Général", value="`/help` `/ping` `/userinfo` `/serverinfo`", inline=False)
    embed.add_field(name="📊 XP & Niveaux", value="`/rank` `/leaderboard`", inline=False)
    embed.add_field(name="🔨 Modération", value="`/kick` `/ban` `/mute` `/unmute` `/clear`", inline=False)
    embed.add_field(name="⚙️ Configuration", value="`/setwelcome`", inline=False)
    embed.set_footer(text="Bot by Yslem")
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="ping", description="Latence du bot")
async def ping(interaction: discord.Interaction):
    latency = round(bot.latency * 1000)
    color = discord.Color.green() if latency < 100 else discord.Color.orange()
    embed = discord.Embed(title="🏓 Pong !", description=f"Latence : **{latency}ms**", color=color)
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="userinfo", description="Informations sur un membre")
@app_commands.describe(membre="Le membre à inspecter")
async def userinfo(interaction: discord.Interaction, membre: discord.Member = None):
    membre = membre or interaction.user
    embed = discord.Embed(title=f"👤 {membre.name}", color=membre.color)
    if membre.avatar:
        embed.set_thumbnail(url=membre.avatar.url)
    embed.add_field(name="ID", value=membre.id, inline=True)
    embed.add_field(name="Surnom", value=membre.nick or "Aucun", inline=True)
    embed.add_field(name="Rejoint le", value=membre.joined_at.strftime("%d/%m/%Y"), inline=True)
    embed.add_field(name="Compte créé le", value=membre.created_at.strftime("%d/%m/%Y"), inline=True)
    roles = [r.mention for r in membre.roles if r.name != "@everyone"]
    embed.add_field(name=f"Rôles ({len(roles)})", value=" ".join(roles) if roles else "Aucun", inline=False)
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="serverinfo", description="Informations sur le serveur")
async def serverinfo(interaction: discord.Interaction):
    guild = interaction.guild
    embed = discord.Embed(title=f"🏠 {guild.name}", color=discord.Color.purple())
    if guild.icon:
        embed.set_thumbnail(url=guild.icon.url)
    embed.add_field(name="👥 Membres", value=guild.member_count, inline=True)
    embed.add_field(name="💬 Salons", value=len(guild.channels), inline=True)
    embed.add_field(name="🎭 Rôles", value=len(guild.roles), inline=True)
    embed.add_field(name="📅 Créé le", value=guild.created_at.strftime("%d/%m/%Y"), inline=True)
    embed.add_field(name="👑 Propriétaire", value=guild.owner.mention, inline=True)
    embed.add_field(name="🌍 Région", value="Auto", inline=True)
    await interaction.response.send_message(embed=embed)

# ========================
# XP & NIVEAUX
# ========================
@bot.tree.command(name="rank", description="Affiche ton niveau et XP")
@app_commands.describe(membre="Le membre à inspecter")
async def rank(interaction: discord.Interaction, membre: discord.Member = None):
    membre = membre or interaction.user
    guild_id = str(interaction.guild.id)
    user_id = str(membre.id)
    if guild_id not in xp_data or user_id not in xp_data[guild_id]:
        await interaction.response.send_message("Pas encore d'XP !", ephemeral=True)
        return
    data = xp_data[guild_id][user_id]
    xp = data["xp"]
    level = data["level"]
    next_xp = ((level + 1) * 10) ** 2
    embed = discord.Embed(title=f"📊 Rang de {membre.name}", color=discord.Color.gold())
    if membre.avatar:
        embed.set_thumbnail(url=membre.avatar.url)
    embed.add_field(name="Niveau", value=f"**{level}**", inline=True)
    embed.add_field(name="XP", value=f"**{xp}** / {next_xp}", inline=True)
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="leaderboard", description="Top 10 des membres les plus actifs")
async def leaderboard(interaction: discord.Interaction):
    guild_id = str(interaction.guild.id)
    if guild_id not in xp_data or not xp_data[guild_id]:
        await interaction.response.send_message("Pas encore de données !", ephemeral=True)
        return
    sorted_users = sorted(xp_data[guild_id].items(), key=lambda x: x[1]["xp"], reverse=True)[:10]
    embed = discord.Embed(title="🏆 Leaderboard XP", color=discord.Color.gold())
    medals = ["🥇", "🥈", "🥉"]
    desc = ""
    for i, (user_id, data) in enumerate(sorted_users):
        medal = medals[i] if i < 3 else f"`{i+1}.`"
        user = interaction.guild.get_member(int(user_id))
        name = user.name if user else f"Membre #{user_id}"
        desc += f"{medal} **{name}** — Nv.{data['level']} ({data['xp']} XP)\n"
    embed.description = desc
    await interaction.response.send_message(embed=embed)

# ========================
# MODÉRATION
# ========================
@bot.tree.command(name="kick", description="Expulser un membre")
@app_commands.describe(membre="Le membre à expulser", raison="La raison")
@app_commands.default_permissions(kick_members=True)
async def kick(interaction: discord.Interaction, membre: discord.Member, raison: str = "Aucune raison"):
    if membre.top_role >= interaction.user.top_role:
        await interaction.response.send_message("❌ Tu ne peux pas expulser ce membre.", ephemeral=True)
        return
    await membre.kick(reason=raison)
    embed = discord.Embed(title="👢 Kick", color=discord.Color.orange())
    embed.add_field(name="Membre", value=membre.mention, inline=True)
    embed.add_field(name="Par", value=interaction.user.mention, inline=True)
    embed.add_field(name="Raison", value=raison, inline=False)
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="ban", description="Bannir un membre")
@app_commands.describe(membre="Le membre à bannir", raison="La raison")
@app_commands.default_permissions(ban_members=True)
async def ban(interaction: discord.Interaction, membre: discord.Member, raison: str = "Aucune raison"):
    if membre.top_role >= interaction.user.top_role:
        await interaction.response.send_message("❌ Tu ne peux pas bannir ce membre.", ephemeral=True)
        return
    await membre.ban(reason=raison)
    embed = discord.Embed(title="🔨 Ban", color=discord.Color.red())
    embed.add_field(name="Membre", value=membre.mention, inline=True)
    embed.add_field(name="Par", value=interaction.user.mention, inline=True)
    embed.add_field(name="Raison", value=raison, inline=False)
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="mute", description="Rendre muet un membre")
@app_commands.describe(membre="Le membre", duree="Durée en minutes", raison="La raison")
@app_commands.default_permissions(moderate_members=True)
async def mute(interaction: discord.Interaction, membre: discord.Member, duree: int = 10, raison: str = "Aucune raison"):
    await membre.timeout(timedelta(minutes=duree), reason=raison)
    embed = discord.Embed(title="🔇 Mute", color=discord.Color.greyple())
    embed.add_field(name="Membre", value=membre.mention, inline=True)
    embed.add_field(name="Durée", value=f"{duree} minutes", inline=True)
    embed.add_field(name="Par", value=interaction.user.mention, inline=True)
    embed.add_field(name="Raison", value=raison, inline=False)
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="unmute", description="Retirer le mute d'un membre")
@app_commands.describe(membre="Le membre")
@app_commands.default_permissions(moderate_members=True)
async def unmute(interaction: discord.Interaction, membre: discord.Member):
    await membre.timeout(None)
    embed = discord.Embed(title="🔊 Unmute", description=f"{membre.mention} peut à nouveau parler.", color=discord.Color.green())
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="clear", description="Supprimer des messages")
@app_commands.describe(nombre="Nombre de messages (max 100)")
@app_commands.default_permissions(manage_messages=True)
async def clear(interaction: discord.Interaction, nombre: int = 10):
    nombre = min(nombre, 100)
    await interaction.response.defer(ephemeral=True)
    deleted = await interaction.channel.purge(limit=nombre)
    await interaction.followup.send(f"🗑️ {len(deleted)} messages supprimés.", ephemeral=True)

# ========================
# CONFIGURATION
# ========================
@bot.tree.command(name="setwelcome", description="Définir le salon de bienvenue")
@app_commands.describe(salon="Le salon")
@app_commands.default_permissions(administrator=True)
async def setwelcome(interaction: discord.Interaction, salon: discord.TextChannel):
    welcome_channels[str(interaction.guild.id)] = str(salon.id)
    save_welcome()
    await interaction.response.send_message(f"✅ Salon de bienvenue : {salon.mention}", ephemeral=True)

# ========================
# LANCEMENT
# ========================
TOKEN = os.environ.get("DISCORD_TOKEN")
if not TOKEN:
    raise ValueError("DISCORD_TOKEN manquant dans les variables d'environnement")
bot.run(TOKEN)
