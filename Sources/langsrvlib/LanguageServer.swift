/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

/// The type of data that is send from the `MessageSource`.
public typealias MessageData = [UInt8]

/// The bottom layer in the messaging stack that is the source of the raw message data.
public protocol MessageSource {
    /// Starts listening for new messages to come in. Whenever a message comes in, the `received`
    /// closure is invoked. This function is not intended to return execution back to its thread.
    func run(received: (MessageData) -> ()) -> Never
}

/// A message protocol is a layer that is used to convert an incoming message of type
/// `MessageData` into a usable `LanguageServerCommand`. If that message cannot be
/// converted, then the `translate` function will throw.
public protocol MessageProtocol {
    /// Translates the data from the raw `MessageData` to a valid `ProtocolDataType`.
    /// This function can throw, providing detailed error information about why the
    /// transformation could not be done.
    func translate(data: MessageData) throws -> LanguageServerCommand
}

/// Defines the API to describe a command for the language server.
/// These currently have a very tight 1:1 mapping with the commands as dictated in the
/// JSONRPC spec. This is by-design to allow for easier development. However, this coupling
/// does **NOT** preclude a different serialization strategy. The only thing it binds is
/// the semantics of the API, which is deemed appropriate at this time.
public protocol LanguageServerCommand {
    var type: CommandType { get }
    var source: CommandSource { get }
}

/// Each language server command has a specific type that requires different logic
/// to handle how it's processed and if it requires a response.
public enum CommandType {
    /// A 1-way message that requires no response.
    case notification

    /// A request that requires a response.
    case request

    /// A response to a particular request.
    case response
}

/// The source that created the message.
public enum CommandSource {
    /// The language server instance.
    case languageServer

    /// The host, usually an editor or IDE.
    case host
}