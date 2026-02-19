import Foundation

struct Motif: Identifiable {
    let id = UUID()
    let name: String
    let meaning: String
    let imageName: String // This will correspond to an image in your Assets
}

// Data for the Library
// In Motif.swift
let mithilaMotifs = [
    Motif(name: "Fish", meaning: "Fertility & Prosperity", imageName: "fish_art"),
    Motif(name: "Peacock", meaning: "Eternity & Love", imageName: "peacock_art"),
    Motif(name: "Sun", meaning: "Source of Life", imageName: "sun_art"),
    Motif(name: "Lotus", meaning: "Purity", imageName: "lotus_art")
]
