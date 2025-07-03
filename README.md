GAZ — Crypto Gas Index

"The next wave of DeFi isn't just about tokens — it's about real economic primitives made accessible, open, and unstoppable."

1. Introduction

Les matières premières jouent un rôle central dans l’économie mondiale, et le gaz naturel y est un actif stratégique pour l’énergie, l’industrie et la géopolitique. Pourtant, l’investissement dans le gaz reste complexe, coûteux et réservé aux professionnels via des dérivés (CFD, futures, ETF). La DeFi a démontré sa capacité à ouvrir des marchés : Bitcoin a désintermédié la monnaie, Ethereum les contrats.

cGAZ vise à désintermédier l’accès au gaz naturel en offrant un jeton synthétique indexé sur son prix spot, sans réserve physique ni promesse de stabilité. Notre solution permet :

Une émission fluide par mint/burn contre stablecoins

Une liquidité sur DEX possible

Une transparence totale via smart contract

2. Problématique & Objectif

Les instruments traditionnels du gaz naturel sont centralisés, coûteux et peu accessibles. cGAZ propose un actif numérique natif, évoluant selon une logique algorithmique et s’intégrant naturellement à l’écosystème Web3, pour offrir une exposition décentralisée et transparente au gaz naturel.

3. Vision & Mission

Vision : Rendre l’accès aux actifs stratégiques (énergie) universel, transparent et interopérable via la blockchain.

Mission : Créer le premier indice numérique natif du gaz naturel, reproduisant sa dynamique de marché, sans promesse de convertibilité physique, tout en assurant rapidité et intégration DeFi.

4. Description Technique du Token

Nom : cGAZ ("Crypto Gas Index")

Symbole : CGAZ

Décimales : 18

Standard : ERC‑20 (déployé sur Arbitrum One)

Offre : Dynamique via mint/burn

4.1. Mint

L’utilisateur envoie des USDC au contrat

Le prix du gaz est récupéré via un oracle

Le contrat calcule : cGAZ = USDC / prix_gaz

Mint du montant calculé, USDC stockés ou brûlés

4.2. Burn

Manuel : par l’équipe pour ajuster la rareté

Automatique : un pourcentage peut être brûlé lors des swaps (ex.—0,1 %)

Remboursement en USDC selon le prix spot : USDC = cGAZ × prix_gaz

5. Upgradabilité et Sécurité

Architecture proxy UUPS (OpenZeppelin) pour permettre des upgrades sans migration complexe

Oracle primaires (TTF CFD, ICE) et fallback (Yahoo Finance)

Suspension automatique en cas de données stale (>6 h) ou variations extrêmes (>±20 %)

6. Utilités du Token

Exposition décentralisée au gaz naturel

Trading 24/7 sur DEX (Uniswap, Camelot)

Intégration dans vaults, pools de liquidité, stratégies DeFi

Alternative aux CFD/ETF traditionnels sans KYC ni comptes brokers

7. Architecture Technique

Smart Contracts : mint, burn, oracle integration, fees 0,5 %

Blockchain : Arbitrum One (L2 Ethereum)

Oracles : Chainlink, API3, RedStone (future intégration)

8. Modèle Économique (Tokenomics)

Frais : 0,5 % sur mint et burn

Utilisation des frais : trésorerie, rémunération des oracles, développement

Offre : élastique, ajustée par mint/burn

9. Gouvernance

Phase 1 : multisig fonda‑tors (centralisé)

Phase 2 : transition vers DAO (vote paramétrage, upgrades)

Paramètres gouvernables : frais, oracles, collatéralisation, allocation des frais

10. Roadmap

Phase

Objectifs clés

Période

1 — Conception

Whitepaper, choix Arbitrum, design

T3 2025

2 — Développement

Testnet, oracles, mint/burn, audit interne

T4 2025

3 — Lancement initial

Mainnet Arbitrum, whitelist, site web

T1 2026

11. Risques

Oracles : pannes, erreurs de données → fallback, gel des fonctions

Liquidité : faible au démarrage → incitatifs de farming

Réglementaire : évolutions MiCA → ajustement vers ART possible

Absence de couverture : purement spéculatif, sans collatéral réel

12. Équipe & Partenaires

Fondateurs : experts énergie + DeFi (stratégie à définir)

Oracles : TradingView/ICE, Yahoo Finance, future Chainlink

Sécurité : audits Sherlock/Hacken/Certik, multisig 2/3

DEX : Uniswap v3, Camelot, Balancer


