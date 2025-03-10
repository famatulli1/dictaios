# Dictaios - Application de Dictaphone iOS

Une application SwiftUI pour enregistrer, sauvegarder et lire des notes vocales sur iOS.

## Comment ouvrir le projet

1. Téléchargez ou clonez ce dépôt sur votre Mac
2. Ouvrez le fichier `Dictaios.xcodeproj` dans Xcode
3. Attendez que Xcode indexe le projet
4. Sélectionnez un simulateur iPhone dans la barre d'outils en haut
5. Cliquez sur le bouton de lecture (▶️) ou appuyez sur Cmd+R pour compiler et exécuter l'application

## Fonctionnalités

- Enregistrement audio avec AVAudioRecorder
- Sauvegarde des fichiers au format .m4a dans le répertoire Documents
- Liste des enregistrements avec date et durée
- Visualisation de forme d'onde (waveform) précise basée sur les données audio réelles
- Lecture des enregistrements avec contrôles et barre de progression
- Suppression des enregistrements par swipe ou menu contextuel
- Interface utilisateur épurée et responsive

## Structure du projet

- **Models/**
  - `AudioRecording.swift` - Modèle représentant un enregistrement audio
  - `AudioFileManager.swift` - Gestion des fichiers audio
  - `AudioAnalyzer.swift` - Extraction et analyse des données audio pour la visualisation
- **ViewModels/**
  - `RecorderViewModel.swift` - Logique d'enregistrement et de lecture
- **Views/**
  - `MainView.swift` - Interface principale
  - `RecordButton.swift` - Bouton d'enregistrement personnalisé
  - `PlayerView.swift` - Interface de lecture des enregistrements
  - `WaveformView.swift` - Visualisation de la forme d'onde audio

## Prérequis

- Xcode 13.0 ou supérieur
- iOS 15.0 ou supérieur (pour le déploiement)

## Remarques

- L'application nécessite l'accès au microphone pour fonctionner
- La permission est demandée lors de la première tentative d'enregistrement
- Les enregistrements sont sauvegardés dans le répertoire Documents de l'application
