//
//  RoomManager.swift
//  ReportChat
//  
//  Created by SATTSAT on 2024/10/22
//  
//

import FirebaseFirestore

final class RoomManager {
    static let shared = RoomManager()
    private let firestore = Firestore.firestore()
    
    private init() {}
    
    //idからルーム情報を取得
    func fetchRoom(roomID: String) async -> RoomResponse? {
        do {
            let snapshot = try await firestore
                .collection("rooms")
                .document(roomID)
                .getDocument()
            
            return try snapshot.data(as: RoomResponse.self)
        } catch _ as NSError {
            print("ルームが見つかりませんでした。")
            return nil
        }
    }
    
    func fetchUserRecentRooms() async -> Result<[RoomResponse], RoomManagerError> {
        guard let loginUser = AppManager.shared.currentUser,
              let loginUserId = loginUser.id else { return .failure(.userNotFound) }
        
        do {
            let snapshot = try await firestore.collection("rooms")
                .whereField("members", arrayContains: loginUserId) // メンバーにユーザーIDが含まれるルームのみ
                .order(by: "lastUpdated", descending: true) // タイムスタンプ順
                .limit(to: 10) // 必要なら、最近の10件だけを取得
                .getDocuments()
            
            let rooms = snapshot.documents.compactMap { document -> RoomResponse? in
                return try? document.data(as: RoomResponse.self)
            }
            
            return .success(rooms)
        } catch {
            return .failure(.roomsFetchError)
        }
    }
    
    // プライベートなルームの作成・存在していればfetchする
    func fetchPrivateRoom(partner: UserResponse) async -> Result<RoomResponse, RoomManagerError> {
        guard let loginUser = AppManager.shared.currentUser,
              let loginUserId = loginUser.id else { return .failure(.userNotFound) }
        guard let partnerId = partner.id else { return .failure(.otherUserNotFound) }
        
        let sortedUIDs = [loginUserId, partnerId].sorted()
        let roomId = "\(sortedUIDs[0])_\(sortedUIDs[1])"
        
        //ルームリストに対象ルームが存在するか確認、あればreturn
        if loginUser.rooms.contains(roomId) {
            guard let fetchedRoom = await fetchRoom(roomID: roomId) else { return .failure(.roomNotFound) }
            return .success(fetchedRoom)
        } else {
            // ルームidがログインユーザーに存在しない場合、新しいルームを作成する
            let newRoom = RoomResponse(
                id: roomId, // ルームIDを設定
                members: [loginUserId, partnerId],
                roomIcon: nil,
                roomName: nil,
                lastUpdated: Date()
            )
            
            do {
                try await firestore
                    .collection("rooms")
                    .document(roomId)
                    .setData(newRoom.toDictionary())
                
                print("新しいルームを作成しました: \(roomId)")
                
                let updateRoomsResult = await addRoom(fromUsers: loginUser, partner, roomId: roomId)
                switch updateRoomsResult {
                case .success(_):
                    print("各ユーザーのルームリスト更新に成功しました")
                    return .success(newRoom)
                case .failure(let error):
                    return .failure(error)
                }
            } catch {
                print("ルームの作成に失敗しました(RoomManager): \(error.localizedDescription)")
                return .failure(.unknownError)
            }
        }
    }
    
    //fromUserのroomsに指定のroomIdを追加する関数
    func addRoom(fromUsers: UserResponse..., roomId: String) async -> Result<Void, RoomManagerError> {
        for fromUser in fromUsers {
            guard let uid = fromUser.id else { return .failure(.userNotFound) }
            
            var updatedRooms: [String] = fromUser.rooms
            
            if !updatedRooms.contains(roomId) {
                updatedRooms.append(roomId)
                
                let updateResult = await updateRooms(userId: uid, data: updatedRooms)
                if case .failure(let error) = updateResult {
                    return .failure(error)
                }
            } else {
                return .failure(.alreadyExists)
            }
        }
        return .success(())
    }
    
    //ルームリストを更新する
    private func updateRooms(userId: String, data: [String]) async -> Result<Void, RoomManagerError> {
        do {
            try await firestore
                .collection("users")
                .document(userId)
                .updateData(["rooms": data])
            return .success(())
        } catch {
            print("フレンドリストの更新に失敗(FriendManager): \(error.localizedDescription)")
            return .failure(.updateFailed)
        }
    }
    
    // ルームのlastUpdatedフィールドを現在の時刻に更新する関数
    func updateRoomLastUpdated(roomId: String) async -> Result<Void, RoomManagerError> {
        do {
            let currentTime = Date()
            try await firestore
                .collection("rooms")
                .document(roomId)
                .updateData(["lastUpdated": currentTime])
            return .success(())
        } catch {
            print("ルームのlastUpdatedフィールドの更新に失敗しました: \(error.localizedDescription)")
            return .failure(.updateFailed)
        }
    }
}
